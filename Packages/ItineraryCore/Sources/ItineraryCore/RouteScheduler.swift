import Foundation

/// Where a stop is in the journey.
public enum StopStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case current
    case visited
    case skipped

    public var label: String {
        switch self {
        case .planned: return "Planned"
        case .current: return "You are here"
        case .visited: return "Visited"
        case .skipped: return "Skipped"
        }
    }
}

/// The minimum a stop needs to have its dates scheduled.
public struct ScheduleInput: Equatable, Sendable {
    public var nights: Int
    public var status: StopStatus
    /// When set, the stop starts on this date no matter what came before it
    /// (e.g. a booked flight). Later stops cascade from here.
    public var pinnedArrival: Date?

    public init(nights: Int, status: StopStatus = .planned, pinnedArrival: Date? = nil) {
        self.nights = nights
        self.status = status
        self.pinnedArrival = pinnedArrival
    }
}

public struct ScheduledDates: Equatable, Sendable {
    public var arrival: Date
    public var departure: Date

    public init(arrival: Date, departure: Date) {
        self.arrival = arrival
        self.departure = departure
    }
}

/// Works out arrival/departure dates for an ordered list of stops.
///
/// Skipped stops take no time: they are given a zero-length window at the
/// point in the route where they would have been, so the rest of the trip
/// slides earlier automatically.
public enum RouteScheduler {
    public static func schedule(
        start: Date,
        stops: [ScheduleInput],
        calendar: Calendar = .current
    ) -> [ScheduledDates] {
        var cursor = calendar.startOfDay(for: start)
        var result: [ScheduledDates] = []
        result.reserveCapacity(stops.count)
        for stop in stops {
            if let pinned = stop.pinnedArrival, stop.status != .skipped {
                cursor = calendar.startOfDay(for: pinned)
            }
            let nights = stop.status == .skipped ? 0 : max(0, stop.nights)
            let departure = calendar.date(byAdding: .day, value: nights, to: cursor) ?? cursor
            result.append(ScheduledDates(arrival: cursor, departure: departure))
            cursor = departure
        }
        return result
    }

    /// Total nights of the trip, ignoring skipped stops.
    public static func totalNights(_ stops: [ScheduleInput]) -> Int {
        stops.filter { $0.status != .skipped }.reduce(0) { $0 + max(0, $1.nights) }
    }

    /// "Get back on route": you are at stop `index` today. Returns the number of
    /// nights that stop should now have so that you leave it on `plannedLeave`
    /// (or, if `plannedLeave` is nil, so the remaining plan is unchanged), and the
    /// pinned arrival date that keeps the schedule anchored to reality.
    ///
    /// - Parameters:
    ///   - arrivedOn: the day you actually arrived at the stop.
    ///   - leavingOn: the day you now intend to leave.
    public static func replan(
        arrivedOn: Date,
        leavingOn: Date,
        calendar: Calendar = .current
    ) -> (pinnedArrival: Date, nights: Int) {
        let a = calendar.startOfDay(for: arrivedOn)
        let l = calendar.startOfDay(for: leavingOn)
        let nights = calendar.dateComponents([.day], from: a, to: l).day ?? 0
        return (a, max(0, nights))
    }

    /// Index of the stop whose window contains `date`, if any.
    public static func indexOfStop(
        on date: Date,
        in schedule: [ScheduledDates],
        calendar: Calendar = .current
    ) -> Int? {
        let day = calendar.startOfDay(for: date)
        return schedule.firstIndex { day >= $0.arrival && day < $0.departure }
    }
}
