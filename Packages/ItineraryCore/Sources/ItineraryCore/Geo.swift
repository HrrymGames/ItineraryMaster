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
        case .bus: return km / 55
        case .train: return km / 70
        case .car: return km / 65
        case .ferry: return km / 30 + 1
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
    case flight, bus, train, car, ferry, walk, other
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .flight: return "airplane"
        case .bus: return "bus.fill"
        case .train: return "tram.fill"
        case .car: return "car.fill"
        case .ferry: return "ferry.fill"
        case .walk: return "figure.walk"
        case .other: return "arrow.triangle.swap"
        }
    }
}
