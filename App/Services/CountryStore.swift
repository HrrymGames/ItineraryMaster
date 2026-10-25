import Foundation
import CoreLocation
import ItineraryCore

struct CurrencyInfo: Codable, Hashable {
    var code: String
    var name: String
    var symbol: String
}

/// Bundled, offline facts about a country.
struct CountryInfo: Codable, Identifiable, Hashable {
    var code: String
    var alpha3: String
    var name: String
    var officialName: String
    var flag: String
    var capital: String
    var region: String
    var subregion: String
    var latitude: Double
    var longitude: Double
    var currencies: [CurrencyInfo]
    var languages: [String]
    var callingCode: String
    var plugs: String
    var drivingSide: String
    var emergency: String
    var dailyCostUSD: Double?
    var tipping: String
    var bestTime: String
    var travelAdviceSlug: String
    var aliases: [String]
    var borders: [String]
    var landlocked: Bool
    var area: Double

    var id: String { code }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var mainCurrency: String { currencies.first?.code ?? "USD" }

    var travelAdviceURL: URL {
        URL(string: "https://www.gov.uk/foreign-travel-advice/\(travelAdviceSlug)")
            ?? URL(string: "https://www.gov.uk/foreign-travel-advice")!
    }

    var entryRequirementsURL: URL {
        URL(string: "https://www.gov.uk/foreign-travel-advice/\(travelAdviceSlug)/entry-requirements")
            ?? travelAdviceURL
    }

    var wikipediaURL: URL {
        URL(string: "https://en.wikipedia.org/wiki/\(name.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)")!
    }
}

/// A well-known place for quick, offline adding and for recognising places in captions.
struct KnownPlace: Codable, Hashable, Identifiable {
    var name: String
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var aliases: [String]
    var id: String { countryCode + name }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

final class CountryStore {
    static let shared = CountryStore()

    let countries: [CountryInfo]
    let places: [KnownPlace]
    private let byCode: [String: CountryInfo]
    private let byAlpha3: [String: CountryInfo]
    let parser: CaptionParser

    private init() {
        func load<T: Decodable>(_ name: String, as: T.Type) -> T? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            do { return try JSONDecoder().decode(T.self, from: data) } catch {
                print("Failed to decode \(name): \(error)")
                return nil
            }
        }
        countries = load("countries", as: [CountryInfo].self) ?? []
        places = load("places", as: [KnownPlace].self) ?? []
        var map: [String: CountryInfo] = [:]
        for c in countries { map[c.code] = c }
        byCode = map
        byAlpha3 = Dictionary(countries.map { ($0.alpha3, $0) }, uniquingKeysWith: { a, _ in a })

        var gazetteer: [GazetteerEntry] = countries.map {
            GazetteerEntry(name: $0.name, countryCode: $0.code, kind: .country, latitude: $0.latitude, longitude: $0.longitude, aliases: $0.aliases)
        }
        gazetteer += places.map {
            GazetteerEntry(name: $0.name, countryCode: $0.countryCode, kind: .city, latitude: $0.latitude, longitude: $0.longitude, aliases: $0.aliases)
        }
        parser = CaptionParser(gazetteer: gazetteer)
    }

    func country(_ code: String?) -> CountryInfo? {
        guard let code, !code.isEmpty else { return nil }
        return byCode[code.uppercased()]
    }

    func country(alpha3: String) -> CountryInfo? { byAlpha3[alpha3.uppercased()] }

    func flag(_ code: String?) -> String {
        guard let code, code.count == 2 else { return "🏳️" }
        return country(code)?.flag ?? code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map(String.init).joined()
    }

    func name(_ code: String?) -> String {
        country(code)?.name ?? (code ?? "Unknown")
    }

    /// Offline search over countries and well-known places.
    func search(_ query: String, limit: Int = 12) -> [KnownPlace] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        func score(_ name: String, _ aliases: [String]) -> Int? {
            let n = name.lowercased()
            if n == q { return 0 }
            if n.hasPrefix(q) { return 1 }
            if aliases.contains(where: { $0.lowercased().hasPrefix(q) }) { return 2 }
            if n.contains(q) { return 3 }
            return nil
        }
        var results: [(Int, KnownPlace)] = []
        for p in places {
            if let s = score(p.name, p.aliases) { results.append((s, p)) }
        }
        for c in countries {
            if let s = score(c.name, c.aliases) {
                // A country "place" lands on its capital if we know it, else its centre.
                let capital = places.first { $0.countryCode == c.code && $0.name == c.capital }
                let p = KnownPlace(name: c.name, countryCode: c.code,
                                   latitude: capital?.latitude ?? c.latitude, longitude: capital?.longitude ?? c.longitude, aliases: [])
                results.append((s + 1, p))
            }
        }
        return results.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.name < $1.1.name }.prefix(limit).map(\.1)
    }

    /// Default per-day spend for a country in the given currency.
    func defaultDailyRate(for code: String, in currency: String, rates: ExchangeRates) -> Double {
        let usd = country(code)?.dailyCostUSD ?? 50
        return rates.convertOrSame(usd, from: "USD", to: currency)
    }

    func analyze(caption: String) -> CaptionAnalysis {
        parser.analyze(caption, extraPlaceNames: NLPlaceTagger.placeNames(in: caption))
    }
}
