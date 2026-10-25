import XCTest
@testable import ItineraryCore

/// Loads the real bundled data from App/Resources so a broken data file fails CI.
enum BundledData {
    static let resources: URL = {
        var u = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { u.deleteLastPathComponent() }
        return u.appendingPathComponent("App/Resources")
    }()

    static func load() throws -> CostDatabase {
        try CostDatabase.load { name in try Data(contentsOf: resources.appendingPathComponent("\(name).json")) }
    }
}

final class BundledDataTests: XCTestCase {
    func testAllCostFilesDecode() throws {
        let db = try BundledData.load()
        XCTAssertEqual(Set(db.countries.keys), ["TH", "VN", "KH", "LA", "ID", "MY", "SG", "PH", "MM"])
        XCTAssertGreaterThan(db.tours.tours.count, 100)
        XCTAssertGreaterThan(db.routes.routes.count, 100)
        XCTAssertGreaterThan(db.places.count, 60)
        XCTAssertFalse(db.fixed.items.isEmpty)
        for c in db.countries.values {
            XCTAssertFalse(c.rules.isEmpty, c.code)
            XCTAssertGreaterThan(c.daily.budget.total, 5, c.code)
            XCTAssertGreaterThan(c.daily.flashpacker.total, c.daily.budget.total, c.code)
        }
        for r in db.routes.routes {
            XCTAssertNotNil(TransportMode(rawValue: r.mode), "\(r.from)-\(r.to) has unknown mode \(r.mode)")
        }
    }

    func testOtherResourcesAreValidJSON() throws {
        for name in ["countries", "places", "templates", "country_shapes"] {
            let data = try Data(contentsOf: BundledData.resources.appendingPathComponent("\(name).json"))
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data), name)
        }
    }
}

final class CostEstimatorTests: XCTestCase {
    var db: CostDatabase!

    override func setUpWithError() throws {
        db = try BundledData.load()
    }

    func testLegFromTableBothDirections() {
        let there = db.estimateLeg(from: "Bangkok", fromCountry: "TH", to: "Chiang Mai", toCountry: "TH", distanceKm: 585, style: .budget)
        XCTAssertEqual(there.mode, .sleeperTrain)
        XCTAssertTrue(there.fromTable)
        let back = db.estimateLeg(from: "Chiang Mai", fromCountry: "TH", to: "Bangkok", toCountry: "TH", distanceKm: 585, style: .budget)
        XCTAssertEqual(back.mode, .sleeperTrain)
        XCTAssertEqual(back.cost, there.cost)
        let slow = db.estimateLeg(from: "Chiang Rai", fromCountry: "TH", to: "Luang Prabang", toCountry: "LA", distanceKm: 300, style: .budget)
        XCTAssertEqual(slow.mode, .slowBoat)
        XCTAssertTrue(slow.tip.contains("Pakbeng"))
    }

    func testLegMatchesAliasesAndAccents() {
        XCTAssertNotNil(db.route(from: "Ho Chi Minh City", to: "Phnom Penh"))
        XCTAssertTrue(PlaceName.matches("Koh Tao Island", "Koh Tao"))
        XCTAssertTrue(PlaceName.matches("Hội An", "Hoi An"))
        XCTAssertFalse(PlaceName.matches("Pai", "Paris"))
    }

    func testLegFallbacks() {
        let far = db.estimateLeg(from: "Somewhere", fromCountry: "TH", to: "Elsewhere", toCountry: "ID", distanceKm: 2500, style: .budget)
        XCTAssertEqual(far.mode, .flight)
        XCTAssertFalse(far.fromTable)
        let near = db.estimateLeg(from: "Town A", fromCountry: "VN", to: "Town B", toCountry: "VN", distanceKm: 200, style: .budget)
        XCTAssertEqual(near.mode, .bus)
        XCTAssertEqual(near.cost, 4)   // 200km x £0.02
        let island = db.estimateLeg(from: "Town A", fromCountry: "TH", to: "Koh Mak", toCountry: "TH", distanceKm: 60, style: .budget)
        XCTAssertEqual(island.mode, .ferry)
        let flash = db.estimateLeg(from: "Town A", fromCountry: "VN", to: "Town B", toCountry: "VN", distanceKm: 200, style: .flashpacker)
        XCTAssertGreaterThan(flash.cost, near.cost)
    }

    func testAccommodationBookedThenSavedThenTypical() {
        let booked = db.accommodationCost(nights: 4, hostels: [HostelInput(pricePerNight: 12, nights: 2, isBooked: true),
                                                               HostelInput(pricePerNight: 30)],
                                          place: "Bangkok", country: "TH", style: .budget)
        XCTAssertEqual(booked.source, .booked)
        XCTAssertEqual(booked.total, 12 * 2 + 10 * 2, accuracy: 0.001)   // 2 booked nights + 2 at Bangkok's typical £10

        let saved = db.accommodationCost(nights: 3, hostels: [HostelInput(pricePerNight: 8), HostelInput(pricePerNight: 12)],
                                         place: "Bangkok", country: "TH", style: .budget)
        XCTAssertEqual(saved.source, .savedHostels)
        XCTAssertEqual(saved.total, 30, accuracy: 0.001)

        let typical = db.accommodationCost(nights: 5, hostels: [], place: "Pai", country: "TH", style: .budget)
        XCTAssertEqual(typical.source, .placeAverage)
        XCTAssertEqual(typical.perNight, 6)

        let country = db.accommodationCost(nights: 2, hostels: [], place: "Unknown Village", country: "VN", style: .flashpacker)
        XCTAssertEqual(country.source, .countryAverage)
        XCTAssertEqual(country.perNight, db.countries["VN"]!.accommodation.privateRoom)
    }

    func testTourMatching() {
        XCTAssertEqual(db.matchTour(name: "ha giang loop")?.place, "Ha Giang")
        XCTAssertEqual(db.matchTour(name: "Ha Giang loop self drive")?.id, "ha-giang-self-drive")
        XCTAssertEqual(db.matchTour(name: "Khao Sok boat tour", place: "Khao Sok", country: "TH")?.place, "Khao Sok")
        XCTAssertEqual(db.matchTour(name: "Halong Bay cruise")?.id, "lan-ha-2d1n")
        XCTAssertNil(db.matchTour(name: "tour"))
        XCTAssertFalse(db.suggestedTours(place: "Hanoi", country: "VN").isEmpty)
        XCTAssertEqual(db.suggestedTours(place: "Khao Sok", country: "TH").first?.place, "Khao Sok")
    }

    func testActivityEstimateFallsBackToBands() {
        let cooking = db.estimateActivity(name: "Vegan cooking workshop", place: "Hanoi", country: "VN", style: .budget)
        XCTAssertNil(cooking.tour)
        XCTAssertEqual(cooking.label, "Cooking class")
        XCTAssertEqual(cooking.price, (22 * 0.8).rounded())
        let unknown = db.estimateActivity(name: "Something fun", place: nil, country: "TH", style: .budget)
        XCTAssertEqual(unknown.price, 20)
    }

    func testFixedCostsScaleAndFollowRoute() {
        let short = db.fixedCosts(countryNights: [("TH", 20)], tripNights: 20, style: .budget)
        let long = db.fixedCosts(countryNights: [("TH", 40), ("VN", 30), ("KH", 10)], tripNights: 80, style: .budget)
        func amount(_ lines: [FixedLine], _ key: String) -> Double? { lines.first { $0.key == key }?.amount }
        XCTAssertEqual(amount(short, "insurance"), 45)
        XCTAssertEqual(amount(long, "insurance"), 45 * 3)            // 80 nights = 3 months
        XCTAssertNil(amount(short, "visa-TH"))                        // within 30 free days
        XCTAssertEqual(amount(long, "visa-TH"), 44)                   // over 30 days -> extension
        XCTAssertNil(amount(long, "visa-VN"))                         // 30 nights < 45 free
        XCTAssertEqual(amount(long, "visa-KH"), 28)
        XCTAssertEqual(long.first { $0.key == "idp-1968" }?.includedByDefault, true)
        XCTAssertEqual(short.first { $0.key == "idp-1968" }?.includedByDefault, false)
        XCTAssertEqual(amount(long, "esim"), 10 * 4)                 // TH 2 x 30-day + VN + KH
    }
}

final class TripPlannerTests: XCTestCase {
    func testPlanAddsEverythingUp() throws {
        let db = try BundledData.load()
        let rates = ExchangeRates(base: "GBP", rates: ["THB": 43])
        let stops = [
            PlanStopInput(id: "1", name: "Bangkok", country: "TH", nights: 3,
                          activities: [("Grand Palace", Money(500, "THB"))]),
            PlanStopInput(id: "2", name: "Chiang Mai", country: "TH", nights: 4,
                          hostels: [(Money(8, "GBP"), nil, true)],
                          previous: ("Bangkok", "TH", 585)),
            PlanStopInput(id: "3", name: "Pai", country: "TH", nights: 2, skipped: true, previous: ("Chiang Mai", "TH", 90)),
        ]
        let plan = TripPlanner.plan(stops: stops, fixed: [(.flights, Money(550, "GBP"), nil)], style: .budget, db: db, rates: rates, currency: "GBP")
        XCTAssertEqual(plan.nights, 7)
        XCTAssertEqual(plan.stops.count, 2)
        XCTAssertEqual(plan.stops[0].accommodation.total, 30, accuracy: 0.01)        // 3 x £10 Bangkok typical
        XCTAssertEqual(plan.stops[1].accommodation.total, 32, accuracy: 0.01)        // booked £8 x 4
        XCTAssertEqual(plan.stops[1].leg?.mode, .sleeperTrain)
        XCTAssertEqual(plan.byCategory[.flights], 550)
        XCTAssertEqual(plan.byCategory[.travel]!, plan.stops[1].legCost, accuracy: 0.01)
        let daily = db.countries["TH"]!.daily.budget
        XCTAssertEqual(plan.byCategory[.food]!, daily.food * 7, accuracy: 0.01)
        XCTAssertEqual(plan.byCategory[.activities]!, daily.activities * 7 + 500 / 43, accuracy: 0.01)
        XCTAssertEqual(plan.total, plan.byCategory.values.reduce(0, +), accuracy: 0.01)
        XCTAssertEqual(plan.fixedTotal, 550)
    }

    func testLegOverrides() throws {
        let db = try BundledData.load()
        let rates = ExchangeRates(base: "GBP", rates: [:])
        let s = PlanStopInput(id: "2", name: "Chiang Mai", country: "TH", nights: 1, previous: ("Bangkok", "TH", 585),
                              legModeOverride: .flight, legCostOverride: Money(42, "GBP"))
        let plan = TripPlanner.plan(stops: [s], fixed: [], style: .budget, db: db, rates: rates, currency: "GBP")
        XCTAssertEqual(plan.stops[0].leg?.mode, .flight)
        XCTAssertEqual(plan.stops[0].legCost, 42)
        XCTAssertFalse(plan.stops[0].legIsTypical)
    }
}

final class DurationTests: XCTestCase {
    func testFormats() {
        XCTAssertEqual(DurationFormat.nights(1), "1 night")
        XCTAssertEqual(DurationFormat.nights(5), "5 nights")
        XCTAssertEqual(DurationFormat.nights(7), "1 week")
        XCTAssertEqual(DurationFormat.nights(17), "2 weeks 3 nights")
        XCTAssertEqual(DurationFormat.nights(30), "1 month")
        XCTAssertEqual(DurationFormat.nights(45), "1 month 2 weeks")
        XCTAssertEqual(DurationFormat.nights(63), "2 months 3 nights")
        XCTAssertEqual(DurationFormat.nights(100), "3 months 1 week")
        XCTAssertEqual(DurationFormat.summary(45), "45 nights · 1 month 2 weeks")
        XCTAssertEqual(DurationFormat.summary(4), "4 nights")
    }
}
