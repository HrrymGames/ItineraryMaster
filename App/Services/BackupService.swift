import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ItineraryCore

/// Export / import everything as one JSON file (photos included).
@MainActor
enum BackupService {
    static func makeBackup(context: ModelContext) -> BackupFile {
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let videos = (try? context.fetch(FetchDescriptor<SavedVideo>())) ?? []
        let lists = (try? context.fetch(FetchDescriptor<PackingList>())) ?? []
        let checklist = (try? context.fetch(FetchDescriptor<ChecklistItem>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<CountryNote>())) ?? []

        return BackupFile(
            trips: trips.map { t in
                TripDTO(
                    id: t.id, name: t.name, startDate: t.startDate, homeCurrency: t.homeCurrency, totalBudget: t.totalBudget,
                    stops: t.orderedStops.map { s in
                        StopDTO(id: s.id, order: s.order, name: s.name, latitude: s.latitude, longitude: s.longitude,
                                countryCode: s.countryCode, nights: s.nights, status: s.statusRaw, pinnedArrival: s.pinnedArrival,
                                notes: s.notes, transportMode: s.transportModeRaw, transportCost: s.transportCost,
                                transportNotes: s.transportNotes, wikiSummary: s.wikiSummary,
                                photos: s.sortedPhotos.map(\.data),
                                items: s.items.map { i in
                                    PlaceItemDTO(id: i.id, kind: i.kindRaw, name: i.name, url: i.url, price: i.price, currency: i.currency,
                                                 notes: i.notes, rating: i.rating, isBooked: i.isBooked, latitude: i.latitude, longitude: i.longitude,
                                                 nights: i.nights, priceIsEstimate: i.priceIsEstimate)
                                },
                                transportModeIsAuto: s.transportModeIsAuto, transportCostOverride: s.transportCostOverride)
                    },
                    budgetLines: t.budgetLines.map {
                        BudgetLineDTO(id: $0.id, name: $0.name, category: $0.categoryRaw, amount: $0.amount, currency: $0.currency, countryCode: $0.countryCode,
                                      autoKey: $0.autoKey, note: $0.note, group: $0.group, isIncluded: $0.isIncluded,
                                      amountEdited: $0.amountEdited, includeOverridden: $0.includeOverridden)
                    },
                    expenses: t.expenses.map {
                        ExpenseDTO(id: $0.id, title: $0.title, category: $0.categoryRaw, amount: $0.amount, currency: $0.currency, date: $0.date, countryCode: $0.countryCode)
                    },
                    travelStyle: t.travelStyleRaw)
            },
            videos: videos.map { v in
                VideoDTO(id: v.id, url: v.urlString, caption: v.caption, author: v.author, thumbnailURL: v.thumbnailURL,
                         categories: v.categoriesRaw, countryCodes: v.countryCodes, placeNames: v.placeNames, notes: v.notes,
                         isSorted: v.isSorted, savedAt: v.savedAt, stopID: v.stop?.id, folder: v.folderRaw)
            },
            packingLists: lists.sorted { $0.order < $1.order }.map { l in
                PackingListDTO(id: l.id, name: l.name, symbol: l.symbol, items: l.items.map { i in
                    PackingItemDTO(id: i.id, name: i.name, category: i.category, quantity: i.quantity, isPacked: i.isPacked,
                                   link: i.link, price: i.price, weightGrams: i.weightGrams, needToBuy: i.needToBuy)
                })
            },
            checklist: checklist.map { ChecklistDTO(id: $0.id, title: $0.title, group: $0.group, isDone: $0.isDone, dueDate: $0.dueDate) },
            countryNotes: notes.map { CountryNoteDTO(countryCode: $0.countryCode, notes: $0.notes, dailyRate: $0.dailyRate) }
        )
    }

    /// Replaces everything in the app with the backup's contents.
    static func restore(_ file: BackupFile, context: ModelContext) throws {
        try wipe(context: context)

        var stopsByID: [UUID: Stop] = [:]
        for t in file.trips {
            let trip = Trip(name: t.name, startDate: t.startDate, homeCurrency: t.homeCurrency, totalBudget: t.totalBudget)
            trip.id = t.id
            if let style = t.travelStyle { trip.travelStyleRaw = style }
            context.insert(trip)
            for s in t.stops {
                let stop = Stop(name: s.name, latitude: s.latitude, longitude: s.longitude, countryCode: s.countryCode, nights: s.nights, order: s.order)
                stop.id = s.id
                stop.statusRaw = s.status
                stop.pinnedArrival = s.pinnedArrival
                stop.notes = s.notes
                stop.transportModeRaw = s.transportMode
                stop.transportCost = s.transportCost
                stop.transportNotes = s.transportNotes
                stop.wikiSummary = s.wikiSummary
                stop.transportModeIsAuto = s.transportModeIsAuto ?? true
                stop.transportCostOverride = s.transportCostOverride
                stop.trip = trip
                context.insert(stop)
                stopsByID[s.id] = stop
                for p in s.photos {
                    let photo = StopPhoto(data: p)
                    photo.stop = stop
                    context.insert(photo)
                }
                for i in s.items {
                    let item = PlaceItem(kind: PlaceKind(rawValue: i.kind) ?? .other, name: i.name, url: i.url, price: i.price, currency: i.currency, notes: i.notes)
                    item.id = i.id
                    item.rating = i.rating
                    item.isBooked = i.isBooked
                    item.latitude = i.latitude
                    item.longitude = i.longitude
                    item.nights = i.nights
                    item.priceIsEstimate = i.priceIsEstimate ?? false
                    item.stop = stop
                    context.insert(item)
                }
            }
            for b in t.budgetLines {
                let line = BudgetLine(name: b.name, category: BudgetCategory(rawValue: b.category) ?? .other, amount: b.amount, currency: b.currency)
                line.id = b.id
                line.countryCode = b.countryCode
                line.autoKey = b.autoKey
                line.note = b.note ?? ""
                line.group = b.group ?? ""
                line.isIncluded = b.isIncluded ?? true
                line.amountEdited = b.amountEdited ?? false
                line.includeOverridden = b.includeOverridden ?? false
                line.trip = trip
                context.insert(line)
            }
            for e in t.expenses {
                let ex = Expense(title: e.title, category: BudgetCategory(rawValue: e.category) ?? .other, amount: e.amount,
                                 currency: e.currency, date: e.date, countryCode: e.countryCode)
                ex.id = e.id
                ex.trip = trip
                context.insert(ex)
            }
        }
        for v in file.videos {
            let video = SavedVideo(urlString: v.url)
            video.id = v.id
            video.caption = v.caption
            video.author = v.author
            video.thumbnailURL = v.thumbnailURL
            video.categoriesRaw = v.categories
            video.countryCodes = v.countryCodes
            video.placeNames = v.placeNames
            video.notes = v.notes
            video.isSorted = v.isSorted
            video.savedAt = v.savedAt
            video.title = v.caption.isEmpty ? "" : CaptionParser.title(from: v.caption)
            video.fetchState = v.caption.isEmpty ? .pending : .fetched
            if let sid = v.stopID { video.stop = stopsByID[sid] }
            video.folderRaw = v.folder
            context.insert(video)
        }
        for (n, l) in file.packingLists.enumerated() {
            let list = PackingList(name: l.name, symbol: l.symbol, order: n)
            list.id = l.id
            context.insert(list)
            for i in l.items {
                let item = PackingItem(name: i.name, category: i.category)
                item.id = i.id
                item.quantity = i.quantity
                item.isPacked = i.isPacked
                item.link = i.link
                item.price = i.price
                item.weightGrams = i.weightGrams
                item.needToBuy = i.needToBuy
                item.list = list
                context.insert(item)
            }
        }
        for c in file.checklist {
            let item = ChecklistItem(title: c.title, group: c.group)
            item.id = c.id
            item.isDone = c.isDone
            item.dueDate = c.dueDate
            context.insert(item)
        }
        for n in file.countryNotes {
            let note = CountryNote(countryCode: n.countryCode)
            note.notes = n.notes
            note.dailyRate = n.dailyRate
            context.insert(note)
        }
        try context.save()
    }

    static func wipe(context: ModelContext) throws {
        try deleteAll(SavedVideo.self, context: context)
        try deleteAll(Trip.self, context: context)        // cascades to stops, items, photos, budget
        try deleteAll(PackingList.self, context: context)  // cascades to items
        try deleteAll(ChecklistItem.self, context: context)
        try deleteAll(CountryNote.self, context: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }
}

/// Wraps a backup so it can be handed to `.fileExporter` / ShareLink.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
