import Foundation

/// A suggested way to get between two stops.
public struct LegEstimate: Equatable, Sendable {
    public var mode: TransportMode
    /// GBP per person.
    public var cost: Double
    public var hours: Double
    public var tip: String
    /// True when it came from the researched route table (vs. a distance-based guess).
    public var fromTable: Bool
}

public struct HostelInput: Equatable, Sendable {
    /// Price per night in GBP.
    public var pricePerNight: Double
    /// nil = the whole stop.
    public var nights: Int?
    public var isBooked: Bool

    public init(pricePerNight: Double, nights: Int? = nil, isBooked: Bool = false) {
        self.pricePerNight = pricePerNight
        self.nights = nights
        self.isBooked = isBooked
    }
}

public enum AccommodationSource: String, Sendable, Equatable {
    case booked, savedHostels, placeAverage, countryAverage, generic

    public var label: String {
        switch self {
        case .booked: return "your booked stays"
        case .savedHostels: return "average of your saved hostels"
        case .placeAverage: return "typical price here"
        case .countryAverage: return "typical price in this country"
        case .generic: return "rough estimate"
        }
    }
}

public struct AccommodationEstimate: Equatable, Sendable {
    public var total: Double
    public var perNight: Double
    public var source: AccommodationSource
}

public struct ActivityEstimate: Equatable, Sendable {
    public var price: Double
    public var label: String
    public var tour: TourInfo?
}

/// One fixed (one-off) cost line generated for a trip.
public struct FixedLine: Equatable, Sendable, Identifiable {
    public var key: String
    public var name: String
    public var category: BudgetCategory
    public var amount: Double
    public var note: String
    public var group: String
    public var includedByDefault: Bool
    public var countryCode: String?
    public var id: String { key }
}

public enum PlaceName {
    /// Lower-case, accent-free, single-spaced, letters and digits only.
    public static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en"))
        var out = ""
        var lastSpace = true
        for ch in folded.lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastSpace = false
            } else if !lastSpace {
                out.append(" ")
                lastSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Same place? Exact match, or one name contains the other as whole words (e.g. "Koh Tao" vs "Koh Tao Island").
    public static func matches(_ a: String, _ b: String) -> Bool {
        let x = normalize(a), y = normalize(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        if x == y { return true }
        let (short, long) = x.count < y.count ? (x, y) : (y, x)
        guard short.count >= 4 else { return false }
        return " \(long) ".contains(" \(short) ")
    }

    static let islandWords = ["koh", "ko", "island", "islands", "gili", "nusa", "isle", "pulau", "phi phi", "perhentian", "boracay", "siargao", "coron", "siquijor", "langkawi", "penida"]

    public static func looksLikeIsland(_ s: String) -> Bool {
        let n = " \(normalize(s)) "
        return islandWords.contains { n.contains(" \($0) ") }
    }
}

extension CostDatabase {
    // MARK: Places & beds

    public func placeCost(named name: String, country: String? = nil) -> PlaceCost? {
        let candidates = country.map { c in places.filter { $0.country == c } } ?? places
        return candidates.first { p in PlaceName.matches(p.place, name) || p.aliases.contains { PlaceName.matches($0, name) } }
            ?? (country != nil ? places.first { p in PlaceName.matches(p.place, name) } : nil)
    }

    /// Typical bed price per night (GBP) for a place.
    public func typicalNightly(place: String, country: String, style: TravelStyle) -> (price: Double, source: AccommodationSource) {
        if let p = placeCost(named: place, country: country) { return (p.price(style), .placeAverage) }
        if let c = countries[country] { return (c.accommodation.price(style), .countryAverage) }
        return (style == .budget ? 12 : 35, .generic)
    }

    /// Accommodation for a stop: booked stays first, then saved hostels' average, then typical prices.
    public func accommodationCost(nights: Int, hostels: [HostelInput], place: String, country: String, style: TravelStyle) -> AccommodationEstimate {
        let n = max(0, nights)
        guard n > 0 else { return AccommodationEstimate(total: 0, perNight: 0, source: .placeAverage) }
        let priced = hostels.filter { $0.pricePerNight > 0 }
        let booked = priced.filter(\.isBooked)
        if !booked.isEmpty {
            var covered = 0
            var total = 0.0
            for h in booked {
                let hn = min(max(0, h.nights ?? n), n - covered)
                total += h.pricePerNight * Double(hn)
                covered += hn
                if covered >= n { break }
            }
            // Nights not covered by bookings use the typical price.
            if covered < n {
                total += typicalNightly(place: place, country: country, style: style).price * Double(n - covered)
            }
            return AccommodationEstimate(total: total, perNight: total / Double(n), source: .booked)
        }
        if !priced.isEmpty {
            let avg = priced.map(\.pricePerNight).reduce(0, +) / Double(priced.count)
            return AccommodationEstimate(total: avg * Double(n), perNight: avg, source: .savedHostels)
        }
        let t = typicalNightly(place: place, country: country, style: style)
        return AccommodationEstimate(total: t.price * Double(n), perNight: t.price, source: t.source)
    }

    // MARK: Daily costs

    public func dailyCosts(country: String, style: TravelStyle) -> DailyCosts {
        if let c = countries[country] { return c.daily.value(style) }
        return style == .budget ? .genericBudget : DailyCosts.genericBudget.scaled(1.7)
    }

    // MARK: Legs

    public func route(from a: String, to b: String) -> (route: RouteInfo, reversed: Bool)? {
        for r in routes.routes {
            if PlaceName.matches(r.from, a) && PlaceName.matches(r.to, b) { return (r, false) }
        }
        for r in routes.routes {
            if PlaceName.matches(r.from, b) && PlaceName.matches(r.to, a) { return (r, true) }
        }
        return nil
    }

    public func estimateLeg(from a: String, fromCountry: String, to b: String, toCountry: String, distanceKm km: Double, style: TravelStyle) -> LegEstimate {
        if let found = route(from: a, to: b) {
            let r = found.route
            return LegEstimate(mode: r.transportMode, cost: r.price(style), hours: r.hours, tip: r.tip, fromTable: true)
        }
        let f = routes.fallback
        let flashMul = style == .flashpacker ? f.flashpackerMultiplier : 1
        let sameCountry = fromCountry == toCountry
        if km > 900 || (!sameCountry && km > 600) {
            let cost = (f.flightBase + f.flightPerKm * km) * flashMul
            return LegEstimate(mode: .flight, cost: cost.rounded(), hours: Geo.estimatedHours(km: km, mode: .flight),
                               tip: "Typical budget-airline fare - book a few weeks ahead.", fromTable: false)
        }
        if km < 3 {
            return LegEstimate(mode: .walk, cost: 0, hours: Geo.estimatedHours(km: km, mode: .walk), tip: "", fromTable: false)
        }
        if PlaceName.looksLikeIsland(a) || PlaceName.looksLikeIsland(b) {
            let cost = (f.ferryDefault + (km > 150 ? 0.03 * km : 0)) * flashMul
            return LegEstimate(mode: .ferry, cost: cost.rounded(), hours: Geo.estimatedHours(km: km, mode: .ferry),
                               tip: "Usually a joint bus + ferry ticket (12Go or a local agency).", fromTable: false)
        }
        let perKm = f.busPerKm[fromCountry] ?? f.busPerKm["default"] ?? 0.03
        let mode: TransportMode = km > 450 ? .sleeperBus : .bus
        let cost = max(f.busMinimum, perKm * km) * flashMul
        return LegEstimate(mode: mode, cost: (cost * 2).rounded() / 2, hours: Geo.estimatedHours(km: km, mode: mode),
                           tip: km > 450 ? "Long trip - an overnight sleeper bus saves a night's accommodation." : "", fromTable: false)
    }

    /// Cost (GBP) of a leg when the user picked a different mode than suggested.
    public func estimateLeg(mode: TransportMode, distanceKm km: Double, country: String, style: TravelStyle) -> Double {
        let f = routes.fallback
        let flashMul = style == .flashpacker ? f.flashpackerMultiplier : 1
        let perKm = f.busPerKm[country] ?? f.busPerKm["default"] ?? 0.03
        let base: Double
        switch mode {
        case .flight: base = f.flightBase + f.flightPerKm * km
        case .ferry: base = f.ferryDefault + (km > 150 ? 0.03 * km : 0)
        case .slowBoat: base = max(15, km * 0.1)
        case .train, .sleeperTrain: base = max(f.busMinimum, perKm * km * 1.3)
        case .car: base = max(8, km * 0.25)
        case .motorbike: base = max(5, km * 0.04)
        case .walk: base = 0
        default: base = max(f.busMinimum, perKm * km)
        }
        return (base * flashMul).rounded()
    }

    // MARK: Tours

    /// Best researched tour for a typed name (e.g. "ha giang loop", "Khao Sok boat").
    public func matchTour(name: String, place: String? = nil, country: String? = nil) -> TourInfo? {
        let query = PlaceName.normalize(name)
        let n = " \(query) "
        guard query.count > 2 else { return nil }
        let multiWord = query.contains(" ")
        var best: (TourInfo, Int)?
        for t in tours.tours {
            var score = 0
            let tn = PlaceName.normalize(t.name)
            if n.contains(" \(tn) ") || (multiWord && " \(tn) ".contains(n)) { score += 5 }
            for k in t.keywords {
                let kn = PlaceName.normalize(k)
                guard n.contains(" \(kn) ") else { continue }
                score += kn.contains(" ") ? 3 : (kn.count >= 5 ? 2 : 1)
            }
            guard score > 0 else { continue }
            if let place, PlaceName.matches(t.place, place) { score += 2 }
            if let country { score += t.country == country ? 1 : -3 }
            if best == nil || score > best!.1 { best = (t, score) }
        }
        // A single generic word (e.g. "tour") isn't enough.
        guard let b = best, b.1 >= 3 else { return nil }
        return b.0
    }

    /// Researched tours for a place first, then the rest of that country.
    public func suggestedTours(place: String, country: String) -> [TourInfo] {
        let here = tours.tours.filter { PlaceName.matches($0.place, place) }
        let rest = tours.tours.filter { $0.country == country && !PlaceName.matches($0.place, place) }
        return here + rest
    }

    /// Price for any activity name: a researched tour, else a typical price for that kind of activity.
    public func estimateActivity(name: String, place: String?, country: String, style: TravelStyle) -> ActivityEstimate {
        if let t = matchTour(name: name, place: place, country: country) {
            return ActivityEstimate(price: t.price(style), label: t.name, tour: t)
        }
        let n = " \(PlaceName.normalize(name)) "
        let factor = tours.countryFactor[country] ?? 1
        let mul = style == .flashpacker ? tours.flashpackerMultiplier : 1
        for band in tours.bands where band.keywords.contains(where: { n.contains(" \(PlaceName.normalize($0)) ") }) {
            return ActivityEstimate(price: (band.budget * factor * mul).rounded(), label: band.label, tour: nil)
        }
        return ActivityEstimate(price: (tours.defaultBudget * factor * mul).rounded(), label: "Typical activity", tour: nil)
    }

    // MARK: Fixed costs

    /// One-off and per-month costs for a trip through these countries.
    /// `countryNights` is in route order; `tripNights` is the whole trip.
    public func fixedCosts(countryNights: [(code: String, nights: Int)], tripNights: Int, style: TravelStyle) -> [FixedLine] {
        let months = max(1, Int((Double(tripNights) / 30).rounded(.up)))
        let codes = countryNights.map(\.code)
        var lines: [FixedLine] = []
        for item in fixed.items {
            var amount = item.price(style)
            var included = item.defaultIncluded
            switch item.per {
            case "month": amount *= Double(months)
            case "country":
                let units = countryNights.reduce(0) { $0 + max(1, Int((Double($1.nights) / 30).rounded(.up))) }
                amount *= Double(max(1, units))
            default: break
            }
            if item.key == "idp-1968" { included = codes.contains("VN") }
            if item.key == "malaria" { included = false }
            lines.append(FixedLine(key: item.key, name: item.name, category: item.budgetCategory, amount: amount,
                                   note: item.note, group: item.group, includedByDefault: included, countryCode: nil))
        }
        var seen = Set<String>()
        for (code, _) in countryNights {
            guard seen.insert(code).inserted, let c = countries[code] else { continue }
            let total = countryNights.filter { $0.code == code }.reduce(0) { $0 + $1.nights }
            let cost = c.visa.cost(forNights: total)
            if cost > 0 || c.visa.freeDays < total {
                var note = c.visa.summary
                if total > c.visa.freeDays && c.visa.freeDays > 0 && !c.visa.longerStayNote.isEmpty { note += " " + c.visa.longerStayNote }
                lines.append(FixedLine(key: "visa-\(code)", name: "Visa", category: .visas, amount: cost, note: note,
                                       group: "Visas & entry", includedByDefault: true, countryCode: code))
            }
            for (i, fee) in c.entryFees.enumerated() {
                lines.append(FixedLine(key: "fee-\(code)-\(i)", name: fee.name, category: .visas, amount: fee.cost, note: fee.note,
                                       group: "Visas & entry", includedByDefault: true, countryCode: code))
            }
        }
        return lines
    }
}
