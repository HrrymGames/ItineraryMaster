import XCTest
@testable import ItineraryCore

final class RouteSchedulerTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testCascadesNights() {
        let s = RouteScheduler.schedule(start: day(2027, 1, 1), stops: [
            ScheduleInput(nights: 3), ScheduleInput(nights: 2), ScheduleInput(nights: 5)
        ], calendar: cal)
        XCTAssertEqual(s.map(\.arrival), [day(2027, 1, 1), day(2027, 1, 4), day(2027, 1, 6)])
        XCTAssertEqual(s.last?.departure, day(2027, 1, 11))
    }

    func testSkippedStopTakesNoTime() {
        let s = RouteScheduler.schedule(start: day(2027, 1, 1), stops: [
            ScheduleInput(nights: 3), ScheduleInput(nights: 4, status: .skipped), ScheduleInput(nights: 2)
        ], calendar: cal)
        XCTAssertEqual(s[1].arrival, s[1].departure)
        XCTAssertEqual(s[2].arrival, day(2027, 1, 4))
        XCTAssertEqual(RouteScheduler.totalNights([ScheduleInput(nights: 3), ScheduleInput(nights: 4, status: .skipped)]), 3)
    }

    func testPinnedArrivalResetsCursor() {
        let s = RouteScheduler.schedule(start: day(2027, 1, 1), stops: [
            ScheduleInput(nights: 3), ScheduleInput(nights: 2, pinnedArrival: day(2027, 2, 1)), ScheduleInput(nights: 1)
        ], calendar: cal)
        XCTAssertEqual(s[1].arrival, day(2027, 2, 1))
        XCTAssertEqual(s[2].arrival, day(2027, 2, 3))
    }

    func testReplanStayLonger() {
        let r = RouteScheduler.replan(arrivedOn: day(2027, 3, 1), leavingOn: day(2027, 3, 9), calendar: cal)
        XCTAssertEqual(r.nights, 8)
        XCTAssertEqual(r.pinnedArrival, day(2027, 3, 1))
    }

    func testIndexOfStopOnDate() {
        let s = RouteScheduler.schedule(start: day(2027, 1, 1), stops: [ScheduleInput(nights: 3), ScheduleInput(nights: 2)], calendar: cal)
        XCTAssertEqual(RouteScheduler.indexOfStop(on: day(2027, 1, 2), in: s, calendar: cal), 0)
        XCTAssertEqual(RouteScheduler.indexOfStop(on: day(2027, 1, 4), in: s, calendar: cal), 1)
        XCTAssertNil(RouteScheduler.indexOfStop(on: day(2027, 1, 6), in: s, calendar: cal))
    }
}

final class CurrencyTests: XCTestCase {
    func testConvertViaBase() {
        let r = ExchangeRates(base: "GBP", rates: ["USD": 1.25, "THB": 45])
        XCTAssertEqual(r.convert(10, from: "GBP", to: "USD")!, 12.5, accuracy: 0.0001)
        XCTAssertEqual(r.convert(450, from: "THB", to: "GBP")!, 10, accuracy: 0.0001)
        XCTAssertEqual(r.convert(12.5, from: "usd", to: "thb")!, 450, accuracy: 0.0001)
        XCTAssertNil(r.convert(1, from: "XXX", to: "GBP"))
        XCTAssertEqual(r.convertOrSame(7, from: "XXX", to: "GBP"), 7)
    }

    func testFillingRebasesMissingCurrencies() {
        let live = ExchangeRates(base: "EUR", rates: ["USD": 1.1])
        let builtIn = ExchangeRates(base: "GBP", rates: ["EUR": 1.2, "VND": 30000, "USD": 1.3])
        let merged = live.filling(from: builtIn)
        XCTAssertEqual(merged.rates["USD"], 1.1)                       // live value kept
        XCTAssertEqual(merged.rates["VND"]!, 25000, accuracy: 0.001)   // 30000 / 1.2
        XCTAssertEqual(merged.rates["GBP"]!, 1 / 1.2, accuracy: 0.0001)
    }
}

final class BudgetTests: XCTestCase {
    func testSummary() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = cal.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        let end = cal.date(from: DateComponents(year: 2027, month: 1, day: 11))!
        let rates = ExchangeRates(base: "GBP", rates: ["USD": 1.25])
        let s = BudgetCalculator.summarize(
            currency: "GBP", totalBudget: 1000,
            stays: [PlannedStay(countryCode: "TH", nights: 10, dailyRate: Money(25, "USD"))],
            fixed: [FixedCost(category: .flights, cost: Money(400, "GBP"))],
            spent: [SpentItem(category: .food, cost: Money(50, "USD"), date: today, countryCode: "th")],
            rates: rates, today: today, tripEnd: end, calendar: cal)
        XCTAssertEqual(s.plannedTotal, 600, accuracy: 0.001)       // 10 × $25 = £200 + £400
        XCTAssertEqual(s.plannedByCountry["TH"]!, 200, accuracy: 0.001)
        XCTAssertEqual(s.plannedByCategory[.accommodation]!, 80, accuracy: 0.001)
        XCTAssertEqual(s.spentTotal, 40, accuracy: 0.001)
        XCTAssertEqual(s.spentByCountry["TH"]!, 40, accuracy: 0.001)
        XCTAssertEqual(s.remaining, 960, accuracy: 0.001)
        XCTAssertEqual(s.daysLeft, 10)
        XCTAssertEqual(s.dailyAllowance, 96, accuracy: 0.001)
        XCTAssertEqual(s.planHeadroom, 400, accuracy: 0.001)
    }
}

final class GeoTests: XCTestCase {
    func testDistance() {
        let london = GeoPoint(latitude: 51.5074, longitude: -0.1278)
        let paris = GeoPoint(latitude: 48.8566, longitude: 2.3522)
        XCTAssertEqual(Geo.distanceKm(london, paris), 344, accuracy: 5)
        XCTAssertEqual(Geo.suggestedMode(km: 2000, sameCountry: false), .flight)
        XCTAssertEqual(Geo.suggestedMode(km: 300, sameCountry: true), .bus)
    }
}

final class CaptionParserTests: XCTestCase {
    let parser = CaptionParser(gazetteer: [
        GazetteerEntry(name: "Vietnam", countryCode: "VN", kind: .country),
        GazetteerEntry(name: "Thailand", countryCode: "TH", kind: .country),
        GazetteerEntry(name: "Hanoi", countryCode: "VN", kind: .city, latitude: 21.03, longitude: 105.85),
        GazetteerEntry(name: "Ha Long Bay", countryCode: "VN", kind: .city, aliases: ["Halong Bay"]),
        GazetteerEntry(name: "Chiang Mai", countryCode: "TH", kind: .city),
        GazetteerEntry(name: "Turkey", countryCode: "TR", kind: .country, aliases: ["Türkiye"]),
        GazetteerEntry(name: "Hue", countryCode: "VN", kind: .city)
    ])

    func testItineraryCaption() {
        let a = parser.analyze("2 weeks in Vietnam 🇻🇳 Hanoi → Ha Long Bay → Hoi An. Total cost £600! #vietnamtravel #backpacking #itinerary")
        XCTAssertEqual(a.primaryCategory, .itinerary)
        XCTAssertEqual(a.durationDays, 14)
        XCTAssertEqual(a.places.map(\.name), ["Vietnam", "Hanoi", "Ha Long Bay"])
        XCTAssertEqual(a.countryCodes, ["VN"])
        XCTAssertEqual(a.prices, [Money(600, "GBP")])
        XCTAssertTrue(a.categories.contains(.budget))
        XCTAssertEqual(a.hashtags, ["vietnamtravel", "backpacking", "itinerary"])
    }

    func testHashtagOnlyCountry() {
        let a = parser.analyze("best hostel I've ever stayed at 😍 #thailand #hostellife")
        XCTAssertEqual(a.countryCodes, ["TH"])
        XCTAssertEqual(a.primaryCategory, .accommodation)
    }

    func testAmbiguousNeedsCapital() {
        XCTAssertTrue(parser.analyze("eating turkey sandwiches").places.isEmpty)
        XCTAssertEqual(parser.analyze("Backpacking Turkey on a budget").places.first?.countryCode, "TR")
        XCTAssertTrue(parser.analyze("what a hue of blue").places.isEmpty)
    }

    func testPackingList() {
        let caption = """
        my backpacking packing list for 3 months 🎒
        - packing cubes
        - quick dry towel
        • universal adapter
        1. power bank
        #packinglist #travelessentials
        """
        let a = parser.analyze(caption)
        XCTAssertEqual(a.primaryCategory, .packing)
        XCTAssertEqual(a.packingItems, ["packing cubes", "quick dry towel", "universal adapter", "power bank"])
    }

    func testInlinePackingList() {
        let a = parser.analyze("Travel essentials: silk sleeping bag liner, padlock, headlamp #packing")
        XCTAssertEqual(a.packingItems, ["silk sleeping bag liner", "padlock", "headlamp"])
    }

    func testWorkExchange() {
        let a = parser.analyze("How I travel for free with Workaway - volunteering for accommodation in Chiang Mai")
        XCTAssertEqual(a.primaryCategory, .work)
        XCTAssertEqual(a.places.first?.name, "Chiang Mai")
    }

    func testPrices() {
        let p = CaptionParser.prices(in: "Hostel was 250 baht, dinner $3.50, flights 1.5k usd and €15")
        XCTAssertEqual(p, [Money(3.5, "USD"), Money(15, "EUR"), Money(250, "THB"), Money(1500, "USD")])
    }

    func testTitleTrims() {
        XCTAssertEqual(CaptionParser.title(from: "Day 1 in Bali #bali\nmore"), "Day 1 in Bali")
        XCTAssertTrue(CaptionParser.title(from: String(repeating: "a", count: 200)).hasSuffix("…"))
    }

    func testTikTokLink() {
        let shared = "Check this out! https://vm.tiktok.com/ZMabc123/ shared via TikTok"
        XCTAssertEqual(TikTokLink.firstURL(in: shared)?.absoluteString, "https://vm.tiktok.com/ZMabc123/")
        let long = "https://www.tiktok.com/@traveller/video/7300000000000000000?is_from_webapp=1"
        XCTAssertEqual(TikTokLink.firstURL(in: long)?.absoluteString, long)
        XCTAssertNil(TikTokLink.firstURL(in: "https://instagram.com/p/x"))
        XCTAssertTrue(TikTokLink.oEmbedURL(for: URL(string: long)!)!.absoluteString.hasPrefix("https://www.tiktok.com/oembed?url="))
        // The link's own query must be encoded so it isn't split into separate parameters.
        XCTAssertFalse(TikTokLink.oEmbedURL(for: URL(string: long)!)!.absoluteString.contains("?is_from_webapp"))
    }
}

final class TikTokLinkTests: XCTestCase {
    func testPostFromFullLinks() {
        XCTAssertEqual(TikTokLink.post(in: "https://www.tiktok.com/@travel.with.me/video/7312345678901234567?is_from_webapp=1&sender_device=pc"),
                       TikTokLink.Post(username: "travel.with.me", id: "7312345678901234567", isPhoto: false))
        XCTAssertEqual(TikTokLink.post(in: "https://www.tiktok.com/@bali_guide/photo/7400000000000000001"),
                       TikTokLink.Post(username: "bali_guide", id: "7400000000000000001", isPhoto: true))
        XCTAssertEqual(TikTokLink.post(in: "https://m.tiktok.com/v/6718335390845095173.html")?.id, "6718335390845095173")
        XCTAssertEqual(TikTokLink.post(in: "https://www.tiktok.com/embed/v2/6718335390845095173")?.id, "6718335390845095173")
        XCTAssertEqual(TikTokLink.post(in: "https://www.tiktok.com/link/v2?aid=1988&share_item_id=7312345678901234567")?.id, "7312345678901234567")
    }

    func testShortLinksNeedResolving() {
        XCTAssertTrue(TikTokLink.needsResolving(URL(string: "https://vm.tiktok.com/ZMabc123/")!))
        XCTAssertTrue(TikTokLink.needsResolving(URL(string: "https://vt.tiktok.com/ZSabc123/")!))
        XCTAssertTrue(TikTokLink.needsResolving(URL(string: "https://www.tiktok.com/t/ZT8abcDEF/")!))
        XCTAssertFalse(TikTokLink.needsResolving(URL(string: "https://www.tiktok.com/@a/video/7312345678901234567")!))
        XCTAssertFalse(TikTokLink.needsResolving(URL(string: "https://www.youtube.com/watch?v=x")!))
    }

    func testCanonicalURL() {
        XCTAssertEqual(TikTokLink.Post(username: nil, id: "123456789", isPhoto: false).canonicalURL.absoluteString,
                       "https://www.tiktok.com/@_/video/123456789")
        XCTAssertEqual(TikTokLink.Post(username: "me", id: "123456789", isPhoto: true).canonicalURL.absoluteString,
                       "https://www.tiktok.com/@me/photo/123456789")
    }

    func testShareSheetTextWithTLink() {
        let text = "Check out this video! https://www.tiktok.com/t/ZT8abcDEF/ #fyp"
        XCTAssertEqual(TikTokLink.firstURL(in: text)?.absoluteString, "https://www.tiktok.com/t/ZT8abcDEF/")
    }

    // Trimmed copy of the structure TikTok serves on post pages.
    static let videoPage = """
    <html><head><title>TikTok - Make Your Day</title></head><body>
    <script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">{"__DEFAULT_SCOPE__":{"webapp.app-context":{"language":"en"},
    "webapp.reflow.video.detail":{"itemInfo":{"itemStruct":{"id":"6718335390845095173",
    "desc":"2 weeks in Vietnam \\u0026 Laos 🇻🇳 #vietnam #backpacking","author":{"uniqueId":"scout2015","nickname":"Scout"},
    "video":{"id":"6718335390845095173","cover":"https://p16-sign.tiktokcdn-us.com/cover.image?x=1&y=2","originCover":"https://o"},
    "challenges":[{"id":"1","desc":"Vietnam challenge","title":"vietnam"}]}}}}}</script></body></html>
    """

    static let photoPage = """
    <script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">{"__DEFAULT_SCOPE__":{"webapp.video-detail":{"itemInfo":{"itemStruct":{
    "id":7400000000000000001,"desc":"Packing list 🎒 - packing cubes, padlock","author":"bali_guide",
    "imagePost":{"cover":{"imageURL":{"urlList":["https://img/cover1.jpeg","https://img/cover2.jpeg"]}},"images":[]}}}}}}</script>
    """

    func testParsesVideoPage() {
        let item = TikTokPage.item(inHTML: Self.videoPage, preferredID: "6718335390845095173")
        XCTAssertEqual(item, TikTokItem(id: "6718335390845095173", caption: "2 weeks in Vietnam & Laos 🇻🇳 #vietnam #backpacking",
                                        author: "scout2015", coverURL: "https://p16-sign.tiktokcdn-us.com/cover.image?x=1&y=2", isPhoto: false))
        // Without a preferred id it still picks the itemStruct, not a hashtag challenge.
        XCTAssertEqual(TikTokPage.item(inHTML: Self.videoPage)?.author, "scout2015")
    }

    func testParsesPhotoPageWithNumericID() {
        let item = TikTokPage.item(inHTML: Self.photoPage)
        XCTAssertEqual(item?.id, "7400000000000000001")
        XCTAssertEqual(item?.author, "bali_guide")
        XCTAssertEqual(item?.coverURL, "https://img/cover1.jpeg")
        XCTAssertEqual(item?.isPhoto, true)
    }

    func testMissingPostDetected() {
        let empty = #"<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">{"__DEFAULT_SCOPE__":{"webapp.app-context":{"language":"en"}}}</script>"#
        XCTAssertNil(TikTokPage.item(inHTML: empty))
        XCTAssertTrue(TikTokPage.looksLikeMissingPost(empty))
        XCTAssertFalse(TikTokPage.looksLikeMissingPost("<html>captcha</html>"))
    }

    func testOpenGraphFallback() {
        let html = """
        <link rel="canonical" href="https://www.tiktok.com/@nomad/video/7311111111111111111">
        <meta property="og:description" content="12K Likes, 300 Comments. TikTok video from Nomad (@nomad): &quot;Hostels in Hanoi under &#36;10 #hanoi&quot;. original sound">
        <meta property="og:image" content="https://img/og.jpg">
        """
        let item = TikTokPage.item(inHTML: html)
        XCTAssertEqual(item?.id, "7311111111111111111")
        XCTAssertEqual(item?.author, "nomad")
        XCTAssertEqual(item?.caption, "Hostels in Hanoi under $10 #hanoi")
        XCTAssertEqual(item?.coverURL, "https://img/og.jpg")
    }
}

final class BackupTests: XCTestCase {
    func testRoundTrip() throws {
        let stop = StopDTO(id: UUID(), order: 0, name: "Hanoi", latitude: 21, longitude: 105, countryCode: "VN", nights: 3,
                           status: "planned", pinnedArrival: nil, notes: "n", transportMode: "bus", transportCost: 10,
                           transportNotes: "", wikiSummary: nil, photos: [Data([1, 2, 3])],
                           items: [PlaceItemDTO(id: UUID(), kind: "hostel", name: "Hostel", url: "", price: 8, currency: "USD",
                                                notes: "", rating: 4, isBooked: true, latitude: nil, longitude: nil)])
        let trip = TripDTO(id: UUID(), name: "Gap year", startDate: Date(timeIntervalSince1970: 1_800_000_000), homeCurrency: "GBP",
                           totalBudget: 8000, stops: [stop], budgetLines: [], expenses: [])
        let file = BackupFile(exportedAt: Date(timeIntervalSince1970: 1_800_000_000), trips: [trip])
        let back = try BackupFile.decode(try file.encoded())
        XCTAssertEqual(back, file)
    }
}
