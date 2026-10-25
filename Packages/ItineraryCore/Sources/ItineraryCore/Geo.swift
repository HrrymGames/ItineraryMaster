import Foundation

public struct GeoPoint: Codable, Equatable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum Geo {
    /// Great-circle distance in kilometres.
    public static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let r = 6371.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    /// Rough door-to-door hours for a leg when no routing service is available.
    public static func estimatedHours(km: Double, mode: TransportMode) -> Double {
        switch mode {
        case .flight: return km / 700 + 3   // airport time
        case .bus, .sleeperBus: return km / 50
        case .minibus: return km / 55
        case .train, .sleeperTrain: return km / 60
        case .car, .motorbike: return km / 55
        case .ferry: return km / 30 + 1
        case .slowBoat: return km / 15
        case .walk: return km / 4.5
        case .other: return km / 50
        }
    }

    /// Picks a sensible default way of getting between two points.
    public static func suggestedMode(km: Double, sameCountry: Bool) -> TransportMode {
        if km > 900 || (!sameCountry && km > 600) { return .flight }
        if km < 3 { return .walk }
        return .bus
    }
}

public enum TransportMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case flight, bus, sleeperBus, minibus, train, sleeperTrain, ferry, slowBoat, car, motorbike, walk, other
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .flight: return "Flight"
        case .bus: return "Bus"
        case .sleeperBus: return "Sleeper bus"
        case .minibus: return "Minibus"
        case .train: return "Train"
        case .sleeperTrain: return "Sleeper train"
        case .ferry: return "Ferry / boat"
        case .slowBoat: return "Slow boat"
        case .car: return "Car / taxi"
        case .motorbike: return "Motorbike"
        case .walk: return "Walk"
        case .other: return "Other"
        }
    }
    public var symbol: String {
        switch self {
        case .flight: return "airplane"
        case .bus, .minibus: return "bus.fill"
        case .sleeperBus: return "bed.double.fill"
        case .train: return "tram.fill"
        case .sleeperTrain: return "train.side.front.car"
        case .ferry: return "ferry.fill"
        case .slowBoat: return "sailboat.fill"
        case .car: return "car.fill"
        case .motorbike: return "scooter"
        case .walk: return "figure.walk"
        case .other: return "arrow.triangle.swap"
        }
    }
}
