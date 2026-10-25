import Foundation
import SwiftUI
import SwiftData
import ItineraryCore

/// Researched SEA costs, tours, routes and rules bundled with the app.
enum Costs {
    static let db: CostDatabase = {
        do {
            return try CostDatabase.load { name in
                guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
                return try Data(contentsOf: url)
            }
        } catch {
            print("Cost data failed to load: \(error)")
            return .empty
        }
    }()

    static var checked: String { db.tours.checked.isEmpty ? "2026" : db.tours.checked }
}

/// Simplified country outlines for the Saved map (Natural Earth, public domain).
enum CountryShapes {
    /// Rings of [lon, lat] points per ISO alpha-2 code.
    static let all: [String: [[[Double]]]] = {
        guard let url = Bundle.main.url(forResource: "country_shapes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [[[Double]]]].self, from: data) else { return [:] }
        return decoded
    }()
}

/// Turns the trip's SwiftData models into planner input and keeps auto budget lines in sync.
@MainActor
enum BudgetSync {
    static func planInputs(for trip: Trip) -> [PlanStopInput] {
        var previous: Stop?
        var out: [PlanStopInput] = []
        for s in trip.orderedStops {
            let hostels = s.items.filter { $0.kind == .hostel && $0.price > 0 }
                .map { (price: Money($0.price, $0.currency), nights: $0.nights, booked: $0.isBooked) }
            let activities = s.items.filter { $0.kind != .hostel && $0.price > 0 }
                .map { (name: $0.name, price: Money($0.price, $0.currency)) }
            var prev: (name: String, country: String, distanceKm: Double)?
            if s.status != .skipped, let p = previous {
                prev = (p.name, p.countryCode, Geo.distanceKm(p.geoPoint, s.geoPoint))
            }
            out.append(PlanStopInput(
                id: s.id.uuidString, name: s.name, country: s.countryCode, nights: s.nights, skipped: s.status == .skipped,
                hostels: hostels, activities: activities, previous: prev,
                legModeOverride: s.transportModeIsAuto ? nil : s.transportMode,
                legCostOverride: s.legCostOverride.map { Money($0, trip.homeCurrency) }))
            if s.status != .skipped { previous = s }
        }
        return out
    }

    static func plan(for trip: Trip, rates: ExchangeRates) -> BudgetPlan {
        let fixed = trip.budgetLines.filter(\.isIncluded).map {
            (category: $0.category, amount: Money($0.amount, $0.currency), countryCode: $0.countryCode)
        }
        return TripPlanner.plan(stops: planInputs(for: trip), fixed: fixed, style: trip.travelStyle,
                                db: Costs.db, rates: rates, currency: trip.homeCurrency)
    }

    /// Nights per country in route order (skipped stops ignored).
    static func countryNights(_ trip: Trip) -> [(code: String, nights: Int)] {
        var order: [String] = []
        var nights: [String: Int] = [:]
        for s in trip.activeStops where !s.countryCode.isEmpty {
            if nights[s.countryCode] == nil { order.append(s.countryCode) }
            nights[s.countryCode, default: 0] += s.nights
        }
        return order.map { ($0, nights[$0] ?? 0) }
    }

    /// A string that changes whenever the auto lines need recalculating.
    static func signature(_ trip: Trip) -> String {
        trip.travelStyleRaw + "|" + countryNights(trip).map { "\($0.code)\($0.nights)" }.joined(separator: ",") + "|\(trip.homeCurrency)"
    }

    /// Creates/updates the researched fixed-cost lines (flights, insurance, visas…).
    /// Lines the user edited keep their amount; lines they switched off stay off.
    static func syncAutoLines(_ trip: Trip, context: ModelContext) {
        let generated = Costs.db.fixedCosts(countryNights: countryNights(trip), tripNights: trip.totalNights, style: trip.travelStyle)
        let existing = trip.budgetLines.filter { $0.autoKey != nil }
        var byKey: [String: BudgetLine] = [:]
        for l in existing { byKey[l.autoKey!] = l }

        for g in generated {
            let name = g.countryCode.map { "\(g.name) · \(CountryStore.shared.flag($0)) \(CountryStore.shared.name($0))" } ?? g.name
            if let line = byKey[g.key] {
                line.name = name
                line.note = g.note
                line.group = g.group
                line.categoryRaw = g.category.rawValue
                line.countryCode = g.countryCode
                if !line.amountEdited {
                    line.amount = g.amount
                    line.currency = "GBP"
                }
                if !line.includeOverridden { line.isIncluded = g.includedByDefault }
                byKey[g.key] = nil
            } else {
                let line = BudgetLine(name: name, category: g.category, amount: g.amount, currency: "GBP")
                line.autoKey = g.key
                line.note = g.note
                line.group = g.group
                line.countryCode = g.countryCode
                line.isIncluded = g.includedByDefault
                line.trip = trip
                context.insert(line)
            }
        }
        // Lines that no longer apply (e.g. a visa for a country you removed).
        for (_, stale) in byKey where !stale.amountEdited {
            context.delete(stale)
        }
    }
}
