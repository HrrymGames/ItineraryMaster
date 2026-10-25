import Foundation
import SwiftData
import CoreLocation
import ItineraryCore

// MARK: - Trip

@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = "My Gap Year"
    var startDate: Date = Date()
    var homeCurrency: String = "GBP"
    var totalBudget: Double = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Stop.trip) var stops: [Stop] = []
    @Relationship(deleteRule: .cascade, inverse: \BudgetLine.trip) var budgetLines: [BudgetLine] = []
    @Relationship(deleteRule: .cascade, inverse: \Expense.trip) var expenses: [Expense] = []

    init(name: String = "My Gap Year", startDate: Date = Date(), homeCurrency: String = "GBP", totalBudget: Double = 0) {
        self.name = name
        self.startDate = startDate
        self.homeCurrency = homeCurrency
        self.totalBudget = totalBudget
    }

    var orderedStops: [Stop] { stops.sorted { $0.order < $1.order } }

    /// Arrival/departure for every stop, keyed by stop id.
    func schedule() -> [UUID: ScheduledDates] {
        let ordered = orderedStops
        let dates = RouteScheduler.schedule(
            start: startDate,
            stops: ordered.map { ScheduleInput(nights: $0.nights, status: $0.status, pinnedArrival: $0.pinnedArrival) }
        )
        var out: [UUID: ScheduledDates] = [:]
        for (stop, d) in zip(ordered, dates) { out[stop.id] = d }
        return out
    }

    var endDate: Date {
        let s = schedule()
        return orderedStops.last.flatMap { s[$0.id]?.departure } ?? startDate
    }

    var totalNights: Int {
        RouteScheduler.totalNights(orderedStops.map { ScheduleInput(nights: $0.nights, status: $0.status) })
    }

    var currentStop: Stop? { orderedStops.first { $0.status == .current } }

    /// Re-numbers `order` so it is 0..n-1 in the current order.
    func normalizeOrder() {
        for (i, s) in orderedStops.enumerated() where s.order != i { s.order = i }
    }

    var countryCodesInRoute: [String] {
        var seen = Set<String>()
        return orderedStops.compactMap { s in
            guard !s.countryCode.isEmpty, s.status != .skipped else { return nil }
            return seen.insert(s.countryCode).inserted ? s.countryCode : nil
        }
    }
}

// MARK: - Stop

@Model
final class Stop {
    var id: UUID = UUID()
    var order: Int = 0
    var name: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var countryCode: String = ""
    var nights: Int = 2
    var statusRaw: String = StopStatus.planned.rawValue
    var pinnedArrival: Date?
    var notes: String = ""
    /// How you get *to* this stop from the previous one.
    var transportModeRaw: String = TransportMode.bus.rawValue
    var transportCost: Double = 0
    var transportNotes: String = ""
    var wikiSummary: String?
    @Attribute(.externalStorage) var wikiImage: Data?
    var createdAt: Date = Date()

    var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \PlaceItem.stop) var items: [PlaceItem] = []
    @Relationship(deleteRule: .cascade, inverse: \StopPhoto.stop) var photos: [StopPhoto] = []
    @Relationship(deleteRule: .nullify, inverse: \SavedVideo.stop) var videos: [SavedVideo] = []

    init(name: String, latitude: Double, longitude: Double, countryCode: String, nights: Int = 2, order: Int = 0) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.countryCode = countryCode.uppercased()
        self.nights = nights
        self.order = order
    }

    var status: StopStatus {
        get { StopStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var transportMode: TransportMode {
        get { TransportMode(rawValue: transportModeRaw) ?? .bus }
        set { transportModeRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var geoPoint: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }

    var sortedPhotos: [StopPhoto] { photos.sorted { $0.createdAt < $1.createdAt } }

    func items(of section: PlaceSection) -> [PlaceItem] {
        items.filter { $0.kind.section == section }.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class StopPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data = Data()
    var caption: String = ""
    var createdAt: Date = Date()
    var stop: Stop?

    init(data: Data) {
        self.data = data
    }
}

// MARK: - Place items (hostels, volunteering, activities…)

enum PlaceKind: String, Codable, CaseIterable, Identifiable {
    case hostel, volunteer, workExchange, job, activity, tour, food, sight, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hostel: return "Hostel / stay"
        case .volunteer: return "Volunteering"
        case .workExchange: return "Work for accommodation"
        case .job: return "Paid work"
        case .activity: return "Activity"
        case .tour: return "Tour"
        case .food: return "Food & drink"
        case .sight: return "Sight / place"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .hostel: return "bed.double.fill"
        case .volunteer: return "heart.fill"
        case .workExchange: return "house.and.flag.fill"
        case .job: return "briefcase.fill"
        case .activity: return "figure.hiking"
        case .tour: return "flag.2.crossed.fill"
        case .food: return "fork.knife"
        case .sight: return "camera.fill"
        case .other: return "star.fill"
        }
    }

    var section: PlaceSection {
        switch self {
        case .hostel: return .stay
        case .volunteer, .workExchange, .job: return .work
        case .activity, .tour: return .todo
        case .food: return .food
        case .sight: return .see
        case .other: return .other
        }
    }

    var budgetCategory: BudgetCategory {
        switch self {
        case .hostel: return .accommodation
        case .activity, .tour: return .activities
        case .food: return .food
        default: return .other
        }
    }
}

enum PlaceSection: String, CaseIterable, Identifiable {
    case stay, work, todo, food, see, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .stay: return "Where to stay"
        case .work: return "Volunteer & work"
        case .todo: return "Activities & tours"
        case .food: return "Food & drink"
        case .see: return "Sights"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .stay: return "bed.double.fill"
        case .work: return "hands.sparkles.fill"
        case .todo: return "figure.hiking"
        case .food: return "fork.knife"
        case .see: return "camera.fill"
        case .other: return "star.fill"
        }
    }

    var defaultKind: PlaceKind {
        switch self {
        case .stay: return .hostel
        case .work: return .workExchange
        case .todo: return .activity
        case .food: return .food
        case .see: return .sight
        case .other: return .other
        }
    }

    /// Web searches that help fill this section for a place.
    func searchLinks(for place: String) -> [(String, URL)] {
        func g(_ q: String) -> URL {
            var c = URLComponents(string: "https://www.google.com/search")!
            c.queryItems = [URLQueryItem(name: "q", value: q)]
            return c.url!
        }
        switch self {
        case .stay:
            return [("Hostelworld", g("hostelworld best hostels \(place)")), ("Booking.com", g("booking.com \(place) hostel"))]
        case .work:
            return [("Worldpackers", g("worldpackers \(place)")), ("Workaway", g("workaway \(place)")), ("Volunteering", g("volunteer projects \(place)"))]
        case .todo:
            return [("GetYourGuide", g("getyourguide \(place)")), ("Things to do", g("best things to do in \(place)"))]
        case .food:
            return [("Where to eat", g("best cheap eats \(place)"))]
        case .see:
            return [("Top sights", g("top sights \(place)"))]
        case .other:
            return []
        }
    }
}

@Model
final class PlaceItem {
    var id: UUID = UUID()
    var kindRaw: String = PlaceKind.activity.rawValue
    var name: String = ""
    var url: String = ""
    var price: Double = 0
    var currency: String = "GBP"
    var notes: String = ""
    var rating: Int = 0
    var isBooked: Bool = false
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date = Date()
    var stop: Stop?

    init(kind: PlaceKind, name: String, url: String = "", price: Double = 0, currency: String = "GBP", notes: String = "") {
        self.kindRaw = kind.rawValue
        self.name = name
        self.url = url
        self.price = price
        self.currency = currency
        self.notes = notes
    }

    var kind: PlaceKind {
        get { PlaceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Countries (user side; facts come from CountryStore)

@Model
final class CountryNote {
    var countryCode: String = ""
    var notes: String = ""
    /// Your own per-day spend estimate, in the trip's home currency.
    var dailyRate: Double?

    init(countryCode: String) {
        self.countryCode = countryCode.uppercased()
    }
}

// MARK: - Saved videos

enum FetchState: String, Codable {
    case pending, fetched, failed, manual
}

@Model
final class SavedVideo {
    var id: UUID = UUID()
    var urlString: String = ""
    var title: String = ""
    var caption: String = ""
    var author: String = ""
    var thumbnailURL: String?
    @Attribute(.externalStorage) var thumbnail: Data?
    var categoriesRaw: [String] = []
    var countryCodes: [String] = []
    var placeNames: [String] = []
    var packingSuggestions: [String] = []
    var priceNotes: [String] = []
    var durationDays: Int?
    var notes: String = ""
    var isSorted: Bool = false
    var isFavourite: Bool = false
    var fetchStateRaw: String = FetchState.pending.rawValue
    /// Why the last fetch failed, shown to the user (nil when fine).
    var fetchError: String?
    /// Whether that failure is worth retrying automatically (no signal, TikTok busy).
    var fetchErrorIsTemporary: Bool = false
    var savedAt: Date = Date()
    var stop: Stop?

    init(urlString: String) {
        self.urlString = urlString
    }

    var url: URL? { URL(string: urlString) }

    var categories: [VideoCategory] {
        get { categoriesRaw.compactMap(VideoCategory.init(rawValue:)) }
        set { categoriesRaw = newValue.map(\.rawValue) }
    }

    var fetchState: FetchState {
        get { FetchState(rawValue: fetchStateRaw) ?? .pending }
        set { fetchStateRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if !caption.isEmpty { return CaptionParser.title(from: caption) }
        return url?.host ?? urlString
    }

    var source: String {
        let host = (url?.host ?? "").lowercased()
        if host.contains("tiktok") { return "TikTok" }
        if host.contains("youtu") { return "YouTube" }
        if host.contains("instagram") { return "Instagram" }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

// MARK: - Packing

@Model
final class PackingList {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "backpack.fill"
    var order: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \PackingItem.list) var items: [PackingItem] = []

    init(name: String, symbol: String = "backpack.fill", order: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.order = order
    }

    var packedCount: Int { items.filter(\.isPacked).count }
    var progress: Double { items.isEmpty ? 0 : Double(packedCount) / Double(items.count) }
}

@Model
final class PackingItem {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = "Other"
    var quantity: Int = 1
    var isPacked: Bool = false
    var link: String = ""
    var price: Double = 0
    var weightGrams: Int = 0
    var needToBuy: Bool = false
    var createdAt: Date = Date()
    var list: PackingList?

    init(name: String, category: String = "Other") {
        self.name = name
        self.category = category
    }
}

@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var title: String = ""
    var group: String = "Before I go"
    var isDone: Bool = false
    var dueDate: Date?
    var createdAt: Date = Date()

    init(title: String, group: String) {
        self.title = title
        self.group = group
    }
}

// MARK: - Budget

@Model
final class BudgetLine {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = BudgetCategory.other.rawValue
    var amount: Double = 0
    var currency: String = "GBP"
    var countryCode: String?
    var trip: Trip?

    init(name: String, category: BudgetCategory, amount: Double, currency: String) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.currency = currency
    }

    var category: BudgetCategory {
        get { BudgetCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class Expense {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = BudgetCategory.food.rawValue
    var amount: Double = 0
    var currency: String = "GBP"
    var date: Date = Date()
    var countryCode: String?
    var trip: Trip?

    init(title: String, category: BudgetCategory, amount: Double, currency: String, date: Date = Date(), countryCode: String? = nil) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.currency = currency
        self.date = date
        self.countryCode = countryCode
    }

    var category: BudgetCategory {
        get { BudgetCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Trip.self, Stop.self, StopPhoto.self, PlaceItem.self, CountryNote.self, SavedVideo.self,
        PackingList.self, PackingItem.self, ChecklistItem.self, BudgetLine.self, Expense.self
    ]
}
