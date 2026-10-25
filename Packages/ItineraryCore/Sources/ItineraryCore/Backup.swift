import Foundation

/// Plain Codable snapshot of everything in the app, used for Export/Import.
/// Sideloaded apps lose their data if deleted, so this is the safety net.
public struct BackupFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var trips: [TripDTO]
    public var videos: [VideoDTO]
    public var packingLists: [PackingListDTO]
    public var checklist: [ChecklistDTO]
    public var countryNotes: [CountryNoteDTO]

    public init(version: Int = BackupFile.currentVersion, exportedAt: Date = Date(), trips: [TripDTO] = [], videos: [VideoDTO] = [],
                packingLists: [PackingListDTO] = [], checklist: [ChecklistDTO] = [], countryNotes: [CountryNoteDTO] = []) {
        self.version = version
        self.exportedAt = exportedAt
        self.trips = trips
        self.videos = videos
        self.packingLists = packingLists
        self.checklist = checklist
        self.countryNotes = countryNotes
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> BackupFile {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(BackupFile.self, from: data)
    }
}

public struct TripDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var startDate: Date
    public var homeCurrency: String
    public var totalBudget: Double
    public var stops: [StopDTO]
    public var budgetLines: [BudgetLineDTO]
    public var expenses: [ExpenseDTO]

    public init(id: UUID, name: String, startDate: Date, homeCurrency: String, totalBudget: Double, stops: [StopDTO],
                budgetLines: [BudgetLineDTO], expenses: [ExpenseDTO]) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.homeCurrency = homeCurrency
        self.totalBudget = totalBudget
        self.stops = stops
        self.budgetLines = budgetLines
        self.expenses = expenses
    }
}

public struct StopDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var order: Int
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var countryCode: String
    public var nights: Int
    public var status: String
    public var pinnedArrival: Date?
    public var notes: String
    public var transportMode: String
    public var transportCost: Double
    public var transportNotes: String
    public var wikiSummary: String?
    public var photos: [Data]
    public var items: [PlaceItemDTO]

    public init(id: UUID, order: Int, name: String, latitude: Double, longitude: Double, countryCode: String, nights: Int,
                status: String, pinnedArrival: Date?, notes: String, transportMode: String, transportCost: Double,
                transportNotes: String, wikiSummary: String?, photos: [Data], items: [PlaceItemDTO]) {
        self.id = id
        self.order = order
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.countryCode = countryCode
        self.nights = nights
        self.status = status
        self.pinnedArrival = pinnedArrival
        self.notes = notes
        self.transportMode = transportMode
        self.transportCost = transportCost
        self.transportNotes = transportNotes
        self.wikiSummary = wikiSummary
        self.photos = photos
        self.items = items
    }
}

public struct PlaceItemDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: String
    public var name: String
    public var url: String
    public var price: Double
    public var currency: String
    public var notes: String
    public var rating: Int
    public var isBooked: Bool
    public var latitude: Double?
    public var longitude: Double?

    public init(id: UUID, kind: String, name: String, url: String, price: Double, currency: String, notes: String,
                rating: Int, isBooked: Bool, latitude: Double?, longitude: Double?) {
        self.id = id
        self.kind = kind
        self.name = name
        self.url = url
        self.price = price
        self.currency = currency
        self.notes = notes
        self.rating = rating
        self.isBooked = isBooked
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct BudgetLineDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var category: String
    public var amount: Double
    public var currency: String
    public var countryCode: String?

    public init(id: UUID, name: String, category: String, amount: Double, currency: String, countryCode: String?) {
        self.id = id
        self.name = name
        self.category = category
        self.amount = amount
        self.currency = currency
        self.countryCode = countryCode
    }
}

public struct ExpenseDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var category: String
    public var amount: Double
    public var currency: String
    public var date: Date
    public var countryCode: String?

    public init(id: UUID, title: String, category: String, amount: Double, currency: String, date: Date, countryCode: String?) {
        self.id = id
        self.title = title
        self.category = category
        self.amount = amount
        self.currency = currency
        self.date = date
        self.countryCode = countryCode
    }
}

public struct VideoDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var url: String
    public var caption: String
    public var author: String
    public var thumbnailURL: String?
    public var categories: [String]
    public var countryCodes: [String]
    public var placeNames: [String]
    public var notes: String
    public var isSorted: Bool
    public var savedAt: Date
    public var stopID: UUID?

    public init(id: UUID, url: String, caption: String, author: String, thumbnailURL: String?, categories: [String],
                countryCodes: [String], placeNames: [String], notes: String, isSorted: Bool, savedAt: Date, stopID: UUID?) {
        self.id = id
        self.url = url
        self.caption = caption
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.categories = categories
        self.countryCodes = countryCodes
        self.placeNames = placeNames
        self.notes = notes
        self.isSorted = isSorted
        self.savedAt = savedAt
        self.stopID = stopID
    }
}

public struct PackingListDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var items: [PackingItemDTO]

    public init(id: UUID, name: String, symbol: String, items: [PackingItemDTO]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.items = items
    }
}

public struct PackingItemDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var category: String
    public var quantity: Int
    public var isPacked: Bool
    public var link: String
    public var price: Double
    public var weightGrams: Int
    public var needToBuy: Bool

    public init(id: UUID, name: String, category: String, quantity: Int, isPacked: Bool, link: String, price: Double,
                weightGrams: Int, needToBuy: Bool) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.isPacked = isPacked
        self.link = link
        self.price = price
        self.weightGrams = weightGrams
        self.needToBuy = needToBuy
    }
}

public struct ChecklistDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var group: String
    public var isDone: Bool
    public var dueDate: Date?

    public init(id: UUID, title: String, group: String, isDone: Bool, dueDate: Date?) {
        self.id = id
        self.title = title
        self.group = group
        self.isDone = isDone
        self.dueDate = dueDate
    }
}

public struct CountryNoteDTO: Codable, Equatable, Sendable {
    public var countryCode: String
    public var notes: String
    public var dailyRate: Double?

    public init(countryCode: String, notes: String, dailyRate: Double?) {
        self.countryCode = countryCode
        self.notes = notes
        self.dailyRate = dailyRate
    }
}
