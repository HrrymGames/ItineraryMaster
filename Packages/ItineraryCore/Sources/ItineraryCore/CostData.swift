import Foundation

/// How you travel - drives which researched figures are used.
public enum TravelStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case budget
    case flashpacker

    public var id: String { rawValue }
    public var label: String { self == .budget ? "Budget backpacker" : "Flashpacker" }
    public var shortLabel: String { self == .budget ? "Budget" : "Flashpacker" }
    public var blurb: String {
        self == .budget
            ? "Dorm beds, street food, local buses, sleeper trains and slow boats."
            : "Private rooms or nice guesthouses, more sit-down meals, more tours and some flights."
    }
}

/// A value researched for both travel styles.
public struct StylePair<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public var budget: T
    public var flashpacker: T

    public init(budget: T, flashpacker: T) {
        self.budget = budget
        self.flashpacker = flashpacker
    }

    public func value(_ style: TravelStyle) -> T { style == .budget ? budget : flashpacker }
}

/// Typical per-day spend (GBP) excluding accommodation.
public struct DailyCosts: Codable, Sendable, Equatable {
    public var food: Double
    public var localTransport: Double
    public var activities: Double
    public var necessities: Double
    public var other: Double

    public init(food: Double, localTransport: Double, activities: Double, necessities: Double, other: Double) {
        self.food = food
        self.localTransport = localTransport
        self.activities = activities
        self.necessities = necessities
        self.other = other
    }

    public var total: Double { food + localTransport + activities + necessities + other }

    public func scaled(_ f: Double) -> DailyCosts {
        DailyCosts(food: food * f, localTransport: localTransport * f, activities: activities * f, necessities: necessities * f, other: other * f)
    }

    /// Used for countries without researched figures.
    public static let genericBudget = DailyCosts(food: 10, localTransport: 5, activities: 5, necessities: 3, other: 5)
}

public struct RoomPrices: Codable, Sendable, Equatable {
    public var dorm: Double
    public var privateRoom: Double

    enum CodingKeys: String, CodingKey {
        case dorm
        case privateRoom = "private"
    }

    public init(dorm: Double, privateRoom: Double) {
        self.dorm = dorm
        self.privateRoom = privateRoom
    }

    /// Budget = dorm bed, flashpacker = private room.
    public func price(_ style: TravelStyle) -> Double { style == .budget ? dorm : privateRoom }
}

public struct VisaInfo: Codable, Sendable, Equatable {
    /// Days you can stay without paying (0 = a visa is always needed).
    public var freeDays: Int
    /// Cost of the visa when one is needed from day one.
    public var cost: Double
    /// Extra cost if you stay beyond `freeDays` (an e-visa or an extension).
    public var longerStayCost: Double
    public var summary: String
    public var how: String
    public var longerStayNote: String

    /// What a stay of `nights` costs in visas/extensions.
    public func cost(forNights nights: Int) -> Double {
        if freeDays == 0 {
            return cost + (nights > 30 ? longerStayCost : 0)
        }
        return nights > freeDays ? longerStayCost : 0
    }
}

public struct EntryFee: Codable, Sendable, Equatable {
    public var name: String
    public var cost: Double
    public var note: String
}

public struct RuleSection: Codable, Sendable, Equatable, Identifiable {
    public var title: String
    public var symbol: String
    public var points: [String]
    public var id: String { title }
}

/// Researched South-East Asia country data (sea_countries.json).
public struct CountryCostInfo: Codable, Sendable, Equatable, Identifiable {
    public var code: String
    public var checked: String
    public var daily: StylePair<DailyCosts>
    public var accommodation: RoomPrices
    public var visa: VisaInfo
    public var entryFees: [EntryFee]
    public var rules: [RuleSection]
    public var spendNote: String
    public var id: String { code }

    /// Full typical day including a bed.
    public func typicalDay(_ style: TravelStyle) -> Double {
        daily.value(style).total + accommodation.price(style)
    }
}

/// Typical bed prices for a place (places_costs.json).
public struct PlaceCost: Codable, Sendable, Equatable {
    public var place: String
    public var country: String
    public var dorm: Double
    public var privateRoom: Double
    public var aliases: [String]

    enum CodingKeys: String, CodingKey {
        case place, country, dorm, aliases
        case privateRoom = "private"
    }

    public func price(_ style: TravelStyle) -> Double { style == .budget ? dorm : privateRoom }
}

public struct TourInfo: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var place: String
    public var country: String
    public var budget: Double
    public var flashpacker: Double
    public var duration: String
    public var keywords: [String]
    public var notes: String
    public var kind: String

    public func price(_ style: TravelStyle) -> Double { style == .budget ? budget : flashpacker }
}

public struct TourBand: Codable, Sendable, Equatable {
    public var keywords: [String]
    public var label: String
    public var budget: Double
}

public struct ToursFile: Codable, Sendable, Equatable {
    public var checked: String
    public var tours: [TourInfo]
    public var bands: [TourBand]
    public var countryFactor: [String: Double]
    public var flashpackerMultiplier: Double
    public var defaultBudget: Double
}

public struct RouteInfo: Codable, Sendable, Equatable {
    public var from: String
    public var to: String
    public var mode: String
    public var budget: Double
    public var flashpacker: Double
    public var hours: Double
    public var tip: String

    public var transportMode: TransportMode { TransportMode(rawValue: mode) ?? .bus }
    public func price(_ style: TravelStyle) -> Double { style == .budget ? budget : flashpacker }
}

public struct RouteFallback: Codable, Sendable, Equatable {
    public var busPerKm: [String: Double]
    public var busMinimum: Double
    public var flightBase: Double
    public var flightPerKm: Double
    public var ferryDefault: Double
    public var flashpackerMultiplier: Double
}

public struct RoutesFile: Codable, Sendable, Equatable {
    public var checked: String
    public var routes: [RouteInfo]
    public var fallback: RouteFallback
}

public struct FixedCostItem: Codable, Sendable, Equatable, Identifiable {
    /// "trip" (once), "month" (per month of travel) or "country" (per country, per 30 days).
    public var key: String
    public var name: String
    public var category: String
    public var budget: Double
    public var flashpacker: Double
    public var per: String
    public var note: String
    public var defaultIncluded: Bool
    public var group: String
    public var id: String { key }

    public var budgetCategory: BudgetCategory { BudgetCategory(rawValue: category) ?? .other }
    public func price(_ style: TravelStyle) -> Double { style == .budget ? budget : flashpacker }
}

public struct FixedCostsFile: Codable, Sendable, Equatable {
    public var checked: String
    public var items: [FixedCostItem]
}

/// Everything researched, loaded from the bundled JSON files.
public struct CostDatabase: Sendable {
    public var countries: [String: CountryCostInfo]
    public var places: [PlaceCost]
    public var tours: ToursFile
    public var routes: RoutesFile
    public var fixed: FixedCostsFile

    public init(countries: [CountryCostInfo], places: [PlaceCost], tours: ToursFile, routes: RoutesFile, fixed: FixedCostsFile) {
        self.countries = Dictionary(countries.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
        self.places = places
        self.tours = tours
        self.routes = routes
        self.fixed = fixed
    }

    public static let fileNames = ["sea_countries", "places_costs", "tours", "transport_routes", "fixed_costs"]

    /// Loads the five JSON files using `data(name)` to fetch each file's bytes.
    public static func load(_ data: (String) throws -> Data) throws -> CostDatabase {
        let d = JSONDecoder()
        return CostDatabase(
            countries: try d.decode([CountryCostInfo].self, from: data("sea_countries")),
            places: try d.decode([PlaceCost].self, from: data("places_costs")),
            tours: try d.decode(ToursFile.self, from: data("tours")),
            routes: try d.decode(RoutesFile.self, from: data("transport_routes")),
            fixed: try d.decode(FixedCostsFile.self, from: data("fixed_costs"))
        )
    }

    public static let empty = CostDatabase(
        countries: [], places: [],
        tours: ToursFile(checked: "", tours: [], bands: [], countryFactor: [:], flashpackerMultiplier: 1.6, defaultBudget: 20),
        routes: RoutesFile(checked: "", routes: [], fallback: RouteFallback(busPerKm: ["default": 0.03], busMinimum: 3, flightBase: 35, flightPerKm: 0.035, ferryDefault: 15, flashpackerMultiplier: 1.5)),
        fixed: FixedCostsFile(checked: "", items: [])
    )
}
