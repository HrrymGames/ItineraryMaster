import Foundation
import NaturalLanguage
import UIKit
import ItineraryCore

enum Net {
    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 30
        c.waitsForConnectivity = false
        c.httpAdditionalHeaders = ["User-Agent": "ItineraryMaster/1.0 (iOS travel planner)"]
        return URLSession(configuration: c)
    }()

    static func json<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MARK: - On-device place-name recognition

enum NLPlaceTagger {
    static func placeNames(in text: String) -> [String] {
        let clean = text.replacingOccurrences(of: "#", with: " ")
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = clean
        var out: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(in: clean.startIndex..<clean.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .placeName {
                let name = String(clean[range])
                if !out.contains(name) { out.append(name) }
            }
            return true
        }
        return out
    }
}

// MARK: - Video metadata (TikTok / YouTube oEmbed, no API key needed)

struct VideoMetadata {
    var caption: String
    var author: String
    var thumbnailURL: String?
    var resolvedURL: URL
}

enum VideoMetadataService {
    static func fetch(_ url: URL) async throws -> VideoMetadata {
        var target = url
        let host = (url.host ?? "").lowercased()

        // Short share links (vm.tiktok.com / vt.tiktok.com) redirect to the full video URL.
        if host.hasPrefix("vm.") || host.hasPrefix("vt.") {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            if let result = try? await Net.session.data(for: req), let final = result.1.url {
                var c = URLComponents(url: final, resolvingAgainstBaseURL: false)
                c?.query = nil
                target = c?.url ?? final
            }
        }

        let endpoint: URL?
        if TikTokLink.isTikTok(target) {
            endpoint = TikTokLink.oEmbedURL(for: target)
        } else if host.contains("youtu") {
            var c = URLComponents(string: "https://www.youtube.com/oembed")
            c?.queryItems = [URLQueryItem(name: "url", value: target.absoluteString), URLQueryItem(name: "format", value: "json")]
            endpoint = c?.url
        } else {
            endpoint = nil
        }
        guard let endpoint else {
            throw URLError(.unsupportedURL)
        }
        let o = try await Net.json(OEmbedResponse.self, from: endpoint)
        return VideoMetadata(caption: o.title ?? "", author: o.author_name ?? "", thumbnailURL: o.thumbnail_url, resolvedURL: target)
    }

    static func thumbnail(from string: String?) async -> Data? {
        guard let string, let url = URL(string: string), let data = try? await Net.data(from: url) else { return nil }
        return ImageTools.downscaled(data, maxDimension: 720, quality: 0.75) ?? data
    }
}

// MARK: - Wikipedia summaries

struct WikiSummary: Decodable {
    struct Image: Decodable { var source: String }
    var type: String?
    var title: String?
    var extract: String?
    var thumbnail: Image?
    var originalimage: Image?
}

enum WikiService {
    static func summary(for title: String) async throws -> WikiSummary {
        let path = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? title
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(path)") else { throw URLError(.badURL) }
        return try await Net.json(WikiSummary.self, from: url)
    }

    /// Tries "Name", then "Name, Country" if the first is a disambiguation page.
    static func bestSummary(place: String, countryName: String?) async -> (text: String, image: Data?)? {
        var candidates = [place]
        if let c = countryName, c != place { candidates.append("\(place), \(c)") }
        for title in candidates {
            guard let s = try? await summary(for: title), s.type != "disambiguation",
                  let text = s.extract, !text.isEmpty else { continue }
            var image: Data?
            if let src = s.originalimage?.source ?? s.thumbnail?.source, let url = URL(string: src),
               let data = try? await Net.data(from: url) {
                image = ImageTools.downscaled(data, maxDimension: 1200, quality: 0.75) ?? data
            }
            return (text, image)
        }
        return nil
    }
}

// MARK: - Exchange rates

final class CurrencyService: ObservableObject {
    static let shared = CurrencyService()

    @Published private(set) var rates: ExchangeRates
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    private static let key = "exchangeRates.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(ExchangeRates.self, from: data) {
            rates = saved.filling(from: .fallbackGBP)
        } else {
            rates = .fallbackGBP
        }
    }

    var isLive: Bool { rates.fetchedAt.timeIntervalSince1970 > 0 }

    private struct OpenERResponse: Decodable {
        var result: String?
        var base_code: String?
        var rates: [String: Double]?
    }

    private struct FrankfurterResponse: Decodable {
        var base: String
        var rates: [String: Double]
    }

    @MainActor
    func refreshIfStale(base: String = "GBP") async {
        if isLive, Date().timeIntervalSince(rates.fetchedAt) < 60 * 60 * 12 { return }
        await refresh(base: base)
    }

    @MainActor
    func refresh(base: String = "GBP") async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let b = base.uppercased()
        var fresh: ExchangeRates?
        if let url = URL(string: "https://open.er-api.com/v6/latest/\(b)"),
           let r = try? await Net.json(OpenERResponse.self, from: url), let map = r.rates, !map.isEmpty {
            fresh = ExchangeRates(base: r.base_code ?? b, rates: map, fetchedAt: Date())
        } else if let url = URL(string: "https://api.frankfurter.app/latest?from=\(b)"),
                  let r = try? await Net.json(FrankfurterResponse.self, from: url) {
            fresh = ExchangeRates(base: r.base, rates: r.rates, fetchedAt: Date())
        }
        guard let fresh else {
            lastError = "Couldn't update rates (offline?). Using saved rates."
            return
        }
        lastError = nil
        rates = fresh.filling(from: rates).filling(from: .fallbackGBP)
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func convert(_ amount: Double, from: String, to: String) -> Double {
        rates.convertOrSame(amount, from: from, to: to)
    }

    /// Currencies we can convert, most useful first.
    var knownCurrencies: [String] {
        let popular = ["GBP", "EUR", "USD", "AUD", "NZD", "THB", "VND", "IDR", "JPY", "INR", "MXN", "PEN", "COP"]
        let rest = rates.rates.keys.filter { !popular.contains($0) }.sorted()
        return popular + rest
    }
}

// MARK: - Images

enum ImageTools {
    static func downscaled(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        if scale >= 1, data.count < 600_000 { return data }
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
