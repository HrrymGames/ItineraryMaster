import Foundation
import SwiftData
import ItineraryCore

private struct Templates: Decodable {
    struct List: Decodable {
        var name: String
        var symbol: String
        var items: [String: [String]]
    }
    var packing: [List]
    var checklist: [String: [String]]

    static func load() -> Templates? {
        guard let url = Bundle.main.url(forResource: "templates", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Templates.self, from: data)
    }
}

/// Creates the first trip and starter lists, and the optional demo trip.
@MainActor
enum Seeder {
    static let checklistOrder = ["3+ months before", "1 month before", "Week before", "On the road"]
    static let packingCategoryOrder = ["Clothes", "Footwear", "Toiletries", "Sleep & hostel", "First aid", "Tech", "Daypack", "Documents", "Money"]

    @discardableResult
    static func ensureTrip(context: ModelContext) -> Trip {
        if let trip = try? context.fetch(FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.createdAt)])).first {
            return trip
        }
        let start = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let trip = Trip(name: "My Gap Year", startDate: start, homeCurrency: "GBP", totalBudget: 6000)
        context.insert(trip)
        seedStarterLists(context: context)
        try? context.save()
        return trip
    }

    static func seedStarterLists(context: ModelContext) {
        let key = "seededStarterLists.v1"
        guard !UserDefaults.standard.bool(forKey: key), let t = Templates.load() else { return }
        UserDefaults.standard.set(true, forKey: key)
        for (n, l) in t.packing.enumerated() {
            let list = PackingList(name: l.name, symbol: l.symbol, order: n)
            context.insert(list)
            let cats = l.items.keys.sorted { (packingCategoryOrder.firstIndex(of: $0) ?? 99) < (packingCategoryOrder.firstIndex(of: $1) ?? 99) }
            var offset = 0.0
            for cat in cats {
                for name in l.items[cat] ?? [] {
                    let item = PackingItem(name: name, category: cat)
                    item.createdAt = Date().addingTimeInterval(offset)
                    offset += 0.001
                    item.list = list
                    context.insert(item)
                }
            }
        }
        var offset = 0.0
        for group in checklistOrder {
            for title in t.checklist[group] ?? [] {
                let item = ChecklistItem(title: title, group: group)
                item.createdAt = Date().addingTimeInterval(offset)
                offset += 0.001
                context.insert(item)
            }
        }
    }

    // MARK: Demo

    static func loadDemo(into trip: Trip, context: ModelContext) {
        let cal = Calendar.current
        trip.name = "South-East Asia Gap Year"
        trip.startDate = cal.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        trip.totalBudget = 6000
        trip.homeCurrency = "GBP"
        for s in trip.stops { context.delete(s) }
        for b in trip.budgetLines { context.delete(b) }
        for e in trip.expenses { context.delete(e) }
        try? context.save()

        let route: [(String, String, Double, Double, Int, TransportMode, Double)] = [
            ("Bangkok", "TH", 13.7563, 100.5018, 4, .flight, 0),
            ("Chiang Mai", "TH", 18.7883, 98.9853, 5, .train, 25),
            ("Pai", "TH", 19.3583, 98.4400, 4, .bus, 8),
            ("Luang Prabang", "LA", 19.8834, 102.1347, 3, .bus, 35),
            ("Vang Vieng", "LA", 18.9235, 102.4478, 3, .train, 12),
            ("Hanoi", "VN", 21.0278, 105.8342, 4, .flight, 70),
            ("Ha Long Bay", "VN", 20.9101, 107.1839, 2, .bus, 15),
            ("Ninh Binh", "VN", 20.2506, 105.9745, 2, .bus, 10),
            ("Hoi An", "VN", 15.8801, 108.3380, 4, .train, 30),
            ("Ho Chi Minh City", "VN", 10.8231, 106.6297, 3, .flight, 40),
            ("Siem Reap", "KH", 13.3671, 103.8448, 3, .bus, 20),
            ("Koh Rong", "KH", 10.7140, 103.2390, 5, .ferry, 25),
            ("Bali", "ID", -8.3405, 115.0920, 10, .flight, 90),
            ("Gili Islands", "ID", -8.3500, 116.0500, 4, .ferry, 30),
        ]
        var stops: [String: Stop] = [:]
        for (i, r) in route.enumerated() {
            let s = Stop(name: r.0, latitude: r.2, longitude: r.3, countryCode: r.1, nights: r.4, order: i)
            // Leave transport on "typical" so the researched route data is used.
            _ = (r.5, r.6)
            s.trip = trip
            context.insert(s)
            stops[r.0] = s
        }
        stops["Bangkok"]?.status = .visited
        stops["Chiang Mai"]?.status = .current
        stops["Bangkok"]?.notes = "Khao San for one night max - stay in Silom/Ari after."

        func item(_ stop: String, _ kind: PlaceKind, _ name: String, price: Double = 0, cur: String = "GBP", booked: Bool = false, url: String = "", notes: String = "") {
            guard let s = stops[stop] else { return }
            let it = PlaceItem(kind: kind, name: name, url: url, price: price, currency: cur, notes: notes)
            it.isBooked = booked
            it.stop = s
            context.insert(it)
        }
        item("Bangkok", .hostel, "Lub d Bangkok Silom", price: 14, booked: true)
        item("Bangkok", .activity, "Grand Palace & Wat Pho", price: 500, cur: "THB")
        item("Bangkok", .food, "Chinatown street food night")
        item("Chiang Mai", .hostel, "Stamps Backpackers", price: 9, booked: true)
        item("Chiang Mai", .volunteer, "Elephant Nature Park volunteer week", price: 12000, cur: "THB", notes: "Ethical - no riding")
        item("Chiang Mai", .tour, "Doi Inthanon day trip", price: 1500, cur: "THB")
        item("Chiang Mai", .activity, "Sunday Night Walking Street")
        item("Pai", .workExchange, "Hostel volunteer (Worldpackers)", notes: "4h/day for bed + breakfast")
        item("Pai", .sight, "Pai Canyon at sunset")
        item("Luang Prabang", .activity, "Kuang Si Falls")
        item("Vang Vieng", .activity, "Blue Lagoon & tubing")
        item("Hanoi", .hostel, "Little Charm Hanoi Hostel", price: 8)
        item("Hanoi", .tour, "Ha Giang Loop - easy rider (3-4 days)", price: 160, notes: "Book a week ahead; leaves from Ha Giang town")
        item("Ha Long Bay", .tour, "Lan Ha Bay cruise (2 days, 1 night)", price: 115)
        item("Siem Reap", .activity, "Angkor pass - 3 days", price: 48)
        item("Luang Prabang", .hostel, "Spicy Laos Backpackers", price: 6)
        item("Hoi An", .activity, "Tailor-made suit + lantern boat")
        item("Bali", .job, "Hostel bar job (Canggu)", notes: "Ask around - casual cash work, check visa rules!")
        item("Bali", .activity, "Mount Batur sunrise trek", price: 35, cur: "USD")

        // Flights, insurance, visas etc. are added automatically by BudgetSync from researched figures.
        let spent: [(String, BudgetCategory, Double, String, Int, String)] = [
            ("Hostel x4", .accommodation, 1680, "THB", -6, "TH"), ("Street food", .food, 950, "THB", -5, "TH"),
            ("Grand Palace", .activities, 500, "THB", -4, "TH"), ("Sleeper train", .transport, 900, "THB", -2, "TH"),
            ("Chiang Mai hostel", .accommodation, 750, "THB", -1, "TH"), ("Khao soi + smoothies", .food, 320, "THB", 0, "TH")
        ]
        for e in spent {
            let x = Expense(title: e.0, category: e.1, amount: e.2, currency: e.3,
                            date: cal.date(byAdding: .day, value: e.4, to: Date()) ?? Date(), countryCode: e.5)
            x.trip = trip
            context.insert(x)
        }

        let captions: [(String, String)] = [
            ("https://www.tiktok.com/@demo/video/7300000000000000001",
             "2 weeks in Vietnam itinerary 🇻🇳 Hanoi → Ha Long Bay → Ninh Binh → Hoi An → Ho Chi Minh City. Spent £600 total! #vietnam #backpacking #itinerary"),
            ("https://www.tiktok.com/@demo/video/7300000000000000002",
             "My backpacking packing list for 6 months 🎒\n- packing cubes\n- quick dry towel\n- universal adapter\n- silk liner\n#packinglist #travelessentials"),
            ("https://www.tiktok.com/@demo/video/7300000000000000003",
             "How I travel for free with Worldpackers - volunteering for accommodation in Chiang Mai 🙌 #workexchange #thailand"),
            ("https://www.tiktok.com/@demo/video/7300000000000000004",
             "Best hostels in Bali under $15 a night 🌴 Canggu, Ubud and Uluwatu #bali #hostel"),
            ("https://www.tiktok.com/@demo/video/7300000000000000005",
             "Things I wish I knew before Laos 🇱🇦 bring USD for the visa on arrival, scams to avoid at the border #laos #traveltips"),
        ]
        for (i, c) in captions.enumerated() {
            let v = SavedVideo(urlString: c.0)
            v.caption = c.1
            v.author = "demo.traveller"
            v.fetchState = .manual
            v.savedAt = Date().addingTimeInterval(Double(-i) * 3600)
            context.insert(v)
            VideoImporter.apply(caption: c.1, to: v, trip: trip)
        }
        trip.normalizeOrder()
        try? context.save()
        BudgetSync.syncAutoLines(trip, context: context)
        try? context.save()
    }
}
