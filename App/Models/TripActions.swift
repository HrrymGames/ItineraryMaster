import Foundation
import SwiftData
import MapKit
import ItineraryCore

extension Trip {
    /// Inserts a new stop. `index` nil = end of the route.
    @discardableResult
    func addStop(_ place: ResolvedPlace, nights: Int, at index: Int?, context: ModelContext) -> Stop {
        var ordered = orderedStops
        let insertAt = min(max(0, index ?? ordered.count), ordered.count)
        let stop = Stop(name: place.name, latitude: place.latitude, longitude: place.longitude,
                        countryCode: place.countryCode, nights: nights, order: insertAt)
        if insertAt > 0 {
            let prev = ordered[insertAt - 1]
            let km = Geo.distanceKm(prev.geoPoint, stop.geoPoint)
            stop.transportMode = Geo.suggestedMode(km: km, sameCountry: prev.countryCode == stop.countryCode)
        } else {
            stop.transportMode = .flight
        }
        stop.trip = self
        context.insert(stop)
        ordered.insert(stop, at: insertAt)
        for (i, s) in ordered.enumerated() { s.order = i }
        try? context.save()
        return stop
    }

    func moveStops(from source: IndexSet, to destination: Int) {
        var ordered = orderedStops
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, s) in ordered.enumerated() { s.order = i }
    }

    func removeStop(_ stop: Stop, context: ModelContext) {
        context.delete(stop)
        let remaining = orderedStops.filter { $0.id != stop.id }
        for (i, s) in remaining.enumerated() { s.order = i }
        try? context.save()
    }

    /// "Get back on route": you're at `stop` now (arrived `arrived`, leaving `leaving`).
    /// Earlier stops become visited, later ones keep their plan but shift dates.
    func setCurrent(_ stop: Stop, arrived: Date, leaving: Date) {
        let r = RouteScheduler.replan(arrivedOn: arrived, leavingOn: leaving)
        var reached = false
        for s in orderedStops {
            if s.id == stop.id {
                reached = true
                s.status = .current
                s.pinnedArrival = r.pinnedArrival
                s.nights = max(1, r.nights)
            } else if !reached {
                if s.status == .planned || s.status == .current { s.status = .visited }
            } else if s.status == .current || s.status == .visited {
                s.status = .planned
            }
        }
    }

    /// Moves "current" to the next non-skipped stop.
    func advance() {
        let ordered = orderedStops
        guard let idx = ordered.firstIndex(where: { $0.status == .current }) else {
            if let first = ordered.first(where: { $0.status == .planned }) {
                setCurrent(first, arrived: Date(), leaving: Calendar.current.date(byAdding: .day, value: max(1, first.nights), to: Date()) ?? Date())
            }
            return
        }
        let cur = ordered[idx]
        cur.status = .visited
        // Leaving today: trim/extend this stop so its departure is today.
        if let arrival = schedule()[cur.id]?.arrival {
            let nights = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: arrival), to: Calendar.current.startOfDay(for: Date())).day ?? cur.nights
            cur.nights = max(0, nights)
            cur.pinnedArrival = arrival
        }
        if let next = ordered[(idx + 1)...].first(where: { $0.status != .skipped }) {
            next.status = .current
        }
    }

    /// How many days you're ahead (+) or behind (-) compared to where the plan says you should be today.
    func daysOffPlan(today: Date = Date()) -> Int? {
        guard let cur = currentStop, let d = schedule()[cur.id] else { return nil }
        let cal = Calendar.current
        let t = cal.startOfDay(for: today)
        if t < d.arrival { return cal.dateComponents([.day], from: t, to: d.arrival).day }
        if t >= d.departure { return -((cal.dateComponents([.day], from: d.departure, to: t).day ?? 0) + 1) }
        return 0
    }

    var activeStops: [Stop] { orderedStops.filter { $0.status != .skipped } }

    func previousActiveStop(before stop: Stop) -> Stop? {
        let active = activeStops
        guard let i = active.firstIndex(where: { $0.id == stop.id }), i > 0 else { return nil }
        return active[i - 1]
    }

    func nextActiveStop(after stop: Stop) -> Stop? {
        let active = activeStops
        guard let i = active.firstIndex(where: { $0.id == stop.id }), i + 1 < active.count else { return nil }
        return active[i + 1]
    }
}

enum MapMath {
    static func region(for coords: [CLLocationCoordinate2D], minSpan: Double = 0.4) -> MKCoordinateRegion? {
        guard let first = coords.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude, minLon = first.longitude, maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(minSpan, (maxLat - minLat) * 1.4),
                                    longitudeDelta: max(minSpan, (maxLon - minLon) * 1.4))
        return MKCoordinateRegion(center: center, span: span)
    }
}
