import Foundation

/// A stop as the planner sees it. All money the user typed comes with its currency.
public struct PlanStopInput: Sendable {
    public var id: String
    public var name: String
    public var country: String
    public var nights: Int
    public var skipped: Bool
    public var hostels: [(price: Money, nights: Int?, booked: Bool)]
    public var activities: [(name: String, price: Money)]
    /// Getting here from the previous active stop (nil for the first stop).
    public var previous: (name: String, country: String, distanceKm: Double)?
    /// User's own choice for this leg; nil = use the typical one.
    public var legModeOverride: TransportMode?
    public var legCostOverride: Money?

    public init(id: String, name: String, country: String, nights: Int, skipped: Bool = false,
                hostels: [(price: Money, nights: Int?, booked: Bool)] = [], activities: [(name: String, price: Money)] = [],
                previous: (name: String, country: String, distanceKm: Double)? = nil,
                legModeOverride: TransportMode? = nil, legCostOverride: Money? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.nights = nights
        self.skipped = skipped
        self.hostels = hostels
        self.activities = activities
        self.previous = previous
        self.legModeOverride = legModeOverride
        self.legCostOverride = legCostOverride
    }
}

public struct StopPlan: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var country: String
    public var nights: Int
    public var accommodation: AccommodationEstimate
    public var daily: DailyCosts
    public var activities: Double
    public var leg: LegEstimate?
    /// Leg cost actually used (override or typical), in the plan currency.
    public var legCost: Double
    public var legIsTypical: Bool

    public var livingTotal: Double { daily.total * Double(nights) }
    public var total: Double { accommodation.total + livingTotal + activities + legCost }
}

public struct BudgetPlan: Sendable, Equatable {
    public var currency: String
    public var stops: [StopPlan]
    public var byCategory: [BudgetCategory: Double]
    public var byCountry: [String: Double]
    public var fixedTotal: Double
    public var total: Double
    public var nights: Int

    public var perDay: Double { nights > 0 ? (total - fixedTotal) / Double(nights) : 0 }

    /// The plan as category lines for `BudgetCalculator`.
    public var asFixedCosts: [FixedCost] {
        byCategory.map { FixedCost(category: $0.key, cost: Money($0.value, currency)) }
    }
}

public enum TripPlanner {
    /// Builds the full plan: beds, daily living, tours, legs and fixed costs.
    /// Researched figures are GBP; everything is converted to `currency`.
    public static func plan(stops: [PlanStopInput], fixed: [(category: BudgetCategory, amount: Money, countryCode: String?)],
                            style: TravelStyle, db: CostDatabase, rates: ExchangeRates, currency: String) -> BudgetPlan {
        let cur = currency.uppercased()
        func gbp(_ v: Double) -> Double { rates.convertOrSame(v, from: "GBP", to: cur) }
        func conv(_ m: Money) -> Double { rates.convertOrSame(m.amount, from: m.currency, to: cur) }

        var byCategory: [BudgetCategory: Double] = [:]
        var byCountry: [String: Double] = [:]
        var plans: [StopPlan] = []
        var nightsTotal = 0

        for s in stops where !s.skipped {
            let nights = max(0, s.nights)
            nightsTotal += nights
            let hostels = s.hostels.map { HostelInput(pricePerNight: rates.convertOrSame($0.price.amount, from: $0.price.currency, to: "GBP"), nights: $0.nights, isBooked: $0.booked) }
            var acc = db.accommodationCost(nights: nights, hostels: hostels, place: s.name, country: s.country, style: style)
            acc.total = gbp(acc.total)
            acc.perNight = gbp(acc.perNight)
            let d = db.dailyCosts(country: s.country, style: style)
            let daily = DailyCosts(food: gbp(d.food), localTransport: gbp(d.localTransport), activities: gbp(d.activities),
                                   necessities: gbp(d.necessities), other: gbp(d.other))
            let activities = s.activities.reduce(0) { $0 + conv($1.price) }

            var leg: LegEstimate?
            var legCost = 0.0
            var typical = true
            if let p = s.previous {
                var e = db.estimateLeg(from: p.name, fromCountry: p.country, to: s.name, toCountry: s.country, distanceKm: p.distanceKm, style: style)
                if let m = s.legModeOverride, m != e.mode {
                    e = LegEstimate(mode: m, cost: db.estimateLeg(mode: m, distanceKm: p.distanceKm, country: s.country, style: style),
                                    hours: Geo.estimatedHours(km: p.distanceKm, mode: m), tip: "", fromTable: false)
                }
                e.cost = gbp(e.cost)
                leg = e
                if let o = s.legCostOverride {
                    legCost = conv(o)
                    typical = false
                } else {
                    legCost = e.cost
                }
            }

            let n = Double(nights)
            byCategory[.accommodation, default: 0] += acc.total
            byCategory[.food, default: 0] += daily.food * n
            byCategory[.transport, default: 0] += daily.localTransport * n
            byCategory[.activities, default: 0] += daily.activities * n + activities
            byCategory[.necessities, default: 0] += daily.necessities * n
            byCategory[.other, default: 0] += daily.other * n
            byCategory[.travel, default: 0] += legCost

            let plan = StopPlan(id: s.id, name: s.name, country: s.country, nights: nights, accommodation: acc, daily: daily,
                                activities: activities, leg: leg, legCost: legCost, legIsTypical: typical)
            byCountry[s.country, default: 0] += plan.total
            plans.append(plan)
        }

        var fixedTotal = 0.0
        for f in fixed {
            let v = conv(f.amount)
            fixedTotal += v
            byCategory[f.category, default: 0] += v
            if let c = f.countryCode { byCountry[c, default: 0] += v }
        }
        byCategory = byCategory.filter { $0.value > 0.004 }
        let total = byCategory.values.reduce(0, +)
        return BudgetPlan(currency: cur, stops: plans, byCategory: byCategory, byCountry: byCountry,
                          fixedTotal: fixedTotal, total: total, nights: nightsTotal)
    }
}

public enum DurationFormat {
    /// "5 nights", "2 weeks 3 nights", "1 month 2 weeks", "3 months".
    public static func nights(_ n: Int) -> String {
        let n = max(0, n)
        if n < 7 { return n == 1 ? "1 night" : "\(n) nights" }
        func plural(_ v: Int, _ word: String) -> String { v == 1 ? "1 \(word)" : "\(v) \(word)s" }
        if n < 30 {
            let w = n / 7, r = n % 7
            return r == 0 ? plural(w, "week") : "\(plural(w, "week")) \(plural(r, "night"))"
        }
        let m = n / 30
        let rest = n % 30
        let w = rest / 7, r = rest % 7
        var parts = [plural(m, "month")]
        if w > 0 { parts.append(plural(w, "week")) }
        if w == 0 && r > 0 { parts.append(plural(r, "night")) }
        return parts.joined(separator: " ")
    }

    /// "45 nights · 1 month 2 weeks" (just "5 nights" when short).
    public static func summary(_ n: Int) -> String {
        n < 7 ? nights(n) : "\(n) nights · \(nights(n))"
    }
}
