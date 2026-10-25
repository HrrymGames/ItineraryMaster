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

// MARK: - Video metadata (no API keys needed)

struct VideoMetadata {
    var caption: String
    var author: String
    var thumbnailURL: String?
    /// Clean link to the post (no tracking query), when we could work it out.
    var canonicalURL: URL?
}

/// Why a video's details couldn't be fetched, in words the user can act on.
enum VideoFetchError: Error, LocalizedError, Equatable {
    case offline
    case notFound
    case blocked(Int)
    case unrecognisedLink
    case unsupportedSite
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .offline: return "No connection - will retry automatically."
        case .notFound: return "TikTok says this post is private, deleted or not available in your region."
        case .blocked(let code): return "TikTok didn't send the details (\(code == 0 ? "busy" : "error \(code)")). Try again in a minute."
        case .unrecognisedLink: return "That doesn't look like a link to a TikTok post."
        case .unsupportedSite: return "Details can't be fetched for this site - add a caption yourself."
        case .failed(let message): return message
        }
    }

    /// Worth retrying in the background later.
    var isTemporary: Bool {
        switch self {
        case .offline, .blocked: return true
        default: return false
        }
    }

    static func from(_ error: Error) -> VideoFetchError {
        if let e = error as? VideoFetchError { return e }
        if let e = error as? URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive, .secureConnectionFailed:
                return .offline
            case .unsupportedURL, .badURL:
                return .unrecognisedLink
            default:
                return .failed("Couldn't load the details (\(e.localizedDescription)).")
            }
        }
        return .failed(error.localizedDescription)
    }
}

enum VideoMetadataService {
    /// TikTok serves full post pages (with the caption data) to normal browsers,
    /// so page requests look like mobile Safari.
    static let browserSession: URLSession = {
        // Ephemeral: no cookies kept between launches, so a bad session can't get stuck.
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        c.timeoutIntervalForResource = 40
        c.waitsForConnectivity = false
        c.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-GB,en;q=0.9"
        ]
        return URLSession(configuration: c)
    }()

    static func fetch(_ url: URL) async throws -> VideoMetadata {
        do {
            if TikTokLink.isTikTok(url) { return try await fetchTikTok(url) }
            if (url.host ?? "").lowercased().contains("youtu") { return try await fetchYouTube(url) }
        } catch {
            throw VideoFetchError.from(error)
        }
        throw VideoFetchError.unsupportedSite
    }

    private static func fetchTikTok(_ url: URL) async throws -> VideoMetadata {
        var post = TikTokLink.post(in: url.absoluteString)

        // 1. Open the shared link itself. Short links (vm./vt./tiktok.com/t/) redirect
        //    to the post page, which usually already holds everything we need.
        let first = try await loadPage(url)
        if post == nil {
            post = TikTokLink.post(in: first.finalURL.absoluteString) ?? TikTokLink.post(inHTML: first.html)
        }
        if let item = TikTokPage.item(inHTML: first.html, preferredID: post?.id) {
            return metadata(from: item, post: post)
        }

        // 2. Open the clean post URL for the id we found.
        guard let post else { throw VideoFetchError.unrecognisedLink }
        let second = try await loadPage(post.canonicalURL)
        if let item = TikTokPage.item(inHTML: second.html, preferredID: post.id) {
            return metadata(from: item, post: post)
        }
        if TikTokPage.looksLikeMissingPost(second.html) { throw VideoFetchError.notFound }
        throw VideoFetchError.blocked(0)
    }

    private static func metadata(from item: TikTokItem, post: TikTokLink.Post?) -> VideoMetadata {
        let author = item.author ?? post?.username ?? ""
        let canonical = TikTokLink.Post(username: author.isEmpty ? nil : author, id: item.id, isPhoto: item.isPhoto).canonicalURL
        return VideoMetadata(caption: item.caption, author: author, thumbnailURL: item.coverURL, canonicalURL: canonical)
    }

    private static func loadPage(_ url: URL) async throws -> (html: String, finalURL: URL) {
        let (data, response) = try await browserSession.data(from: url)
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 404, 410: throw VideoFetchError.notFound
            default: throw VideoFetchError.blocked(http.statusCode)
            }
        }
        return (String(decoding: data, as: UTF8.self), response.url ?? url)
    }

    private static func fetchYouTube(_ url: URL) async throws -> VideoMetadata {
        var c = URLComponents(string: "https://www.youtube.com/oembed")
        c?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString), URLQueryItem(name: "format", value: "json")]
        guard let endpoint = c?.url else { throw VideoFetchError.unrecognisedLink }
        let (data, response) = try await Net.session.data(from: endpoint)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw http.statusCode == 404 || http.statusCode == 401 ? VideoFetchError.notFound : VideoFetchError.blocked(http.statusCode)
        }
        let o = try JSONDecoder().decode(OEmbedResponse.self, from: data)
        return VideoMetadata(caption: o.title ?? "", author: o.author_name ?? "", thumbnailURL: o.thumbnail_url, canonicalURL: nil)
    }

    static func thumbnail(from string: String?) async -> Data? {
        guard let string, let url = URL(string: string),
              let result = try? await browserSession.data(from: url) else { return nil }
        let (data, response) = result
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        guard !data.isEmpty else { return nil }
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
