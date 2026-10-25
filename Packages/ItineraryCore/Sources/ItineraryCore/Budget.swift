import Foundation

public enum BudgetCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case accommodation
    case food
    case transport
    case travel
    case activities
    case necessities
    case flights
    case insurance
    case gear
    case visas
    case shopping
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .accommodation: return "Accommodation"
        case .food: return "Food & drink"
        case .transport: return "Getting around"
        case .travel: return "Between stops"
        case .activities: return "Activities & tours"
        case .necessities: return "Necessities & SIM"
        case .flights: return "Flights"
        case .insurance: return "Insurance & health"
        case .gear: return "Gear"
        case .visas: return "Visas & fees"
        case .shopping: return "Shopping"
        case .other: return "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .accommodation: return "bed.double.fill"
        case .food: return "fork.knife"
        case .transport: return "bus.fill"
        case .travel: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .activities: return "figure.hiking"
        case .necessities: return "basket.fill"
        case .flights: return "airplane"
        case .insurance: return "cross.case.fill"
        case .gear: return "backpack.fill"
        case .visas: return "doc.text.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// How a backpacker's daily spend is typically split. Used to break a
    /// country's single "per day" figure into categories.
    public static let dailyShare: [BudgetCategory: Double] = [
        .accommodation: 0.40,
        .food: 0.30,
        .activities: 0.15,
        .transport: 0.15
    ]
}

public struct Money: Codable, Equatable, Sendable {
    public var amount: Double
    public var currency: String
    public init(_ amount: Double, _ currency: String) {
        self.amount = amount
        self.currency = currency.uppercased()
    }
}

public struct PlannedStay: Equatable, Sendable {
    public var countryCode: String
    public var nights: Int
    /// What you expect to spend per day while here, all-in.
    public var dailyRate: Money
    public init(countryCode: String, nights: Int, dailyRate: Money) {
        self.countryCode = countryCode
        self.nights = nights
        self.dailyRate = dailyRate
    }
}

public struct FixedCost: Equatable, Sendable {
    public var category: BudgetCategory
    public var cost: Money
    public var countryCode: String?
    public init(category: BudgetCategory, cost: Money, countryCode: String? = nil) {
        self.category = category
        self.cost = cost
        self.countryCode = countryCode
    }
}

public struct SpentItem: Equatable, Sendable {
    public var category: BudgetCategory
    public var cost: Money
    public var date: Date
    public var countryCode: String?
    public init(category: BudgetCategory, cost: Money, date: Date, countryCode: String? = nil) {
        self.category = category
        self.cost = cost
        self.date = date
        self.countryCode = countryCode
    }
}

public struct BudgetSummary: Equatable, Sendable {
    public var currency: String
    public var totalBudget: Double
    public var plannedTotal: Double
    public var plannedByCategory: [BudgetCategory: Double]
    public var plannedByCountry: [String: Double]
    public var spentTotal: Double
    public var spentByCategory: [BudgetCategory: Double]
    public var spentByCountry: [String: Double]
    public var daysLeft: Int
    public var tripNights: Int

    /// Money left once everything you've spent is taken off.
    public var remaining: Double { totalBudget - spentTotal }
    /// Budget minus the full plan: negative means the plan is over budget.
    public var planHeadroom: Double { totalBudget - plannedTotal }
    /// What you can spend per remaining day and still finish on budget.
    public var dailyAllowance: Double { daysLeft > 0 ? remaining / Double(daysLeft) : remaining }
    /// Average planned spend per night across the trip.
    public var plannedPerDay: Double { tripNights > 0 ? plannedTotal / Double(tripNights) : 0 }
    /// 0...1+ share of the budget already spent.
    public var spentFraction: Double { totalBudget > 0 ? spentTotal / totalBudget : 0 }
}

public enum BudgetCalculator {
    public static func summarize(
        currency: String,
        totalBudget: Double,
        stays: [PlannedStay],
        fixed: [FixedCost],
        spent: [SpentItem],
        rates: ExchangeRates,
        today: Date = Date(),
        tripEnd: Date?,
        calendar: Calendar = .current
    ) -> BudgetSummary {
        let cur = currency.uppercased()
        func conv(_ m: Money) -> Double { rates.convertOrSame(m.amount, from: m.currency, to: cur) }

        var plannedByCategory: [BudgetCategory: Double] = [:]
        var plannedByCountry: [String: Double] = [:]

        for stay in stays where stay.nights > 0 {
            let total = conv(stay.dailyRate) * Double(stay.nights)
            for (cat, share) in BudgetCategory.dailyShare {
                plannedByCategory[cat, default: 0] += total * share
            }
            plannedByCountry[stay.countryCode.uppercased(), default: 0] += total
        }
        for f in fixed {
            let v = conv(f.cost)
            plannedByCategory[f.category, default: 0] += v
            if let cc = f.countryCode, !cc.isEmpty {
                plannedByCountry[cc.uppercased(), default: 0] += v
            }
        }

        var spentByCategory: [BudgetCategory: Double] = [:]
        var spentByCountry: [String: Double] = [:]
        for s in spent {
            let v = conv(s.cost)
            spentByCategory[s.category, default: 0] += v
            if let cc = s.countryCode, !cc.isEmpty {
                spentByCountry[cc.uppercased(), default: 0] += v
            }
        }

        var daysLeft = 0
        if let end = tripEnd {
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: end)).day ?? 0
            daysLeft = max(0, d)
        }

        return BudgetSummary(
            currency: cur,
            totalBudget: totalBudget,
            plannedTotal: plannedByCategory.values.reduce(0, +),
            plannedByCategory: plannedByCategory,
            plannedByCountry: plannedByCountry,
            spentTotal: spentByCategory.values.reduce(0, +),
            spentByCategory: spentByCategory,
            spentByCountry: spentByCountry,
            daysLeft: daysLeft,
            tripNights: stays.reduce(0) { $0 + max(0, $1.nights) }
        )
    }
}
