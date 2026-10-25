import Foundation
import MapKit
import CoreLocation
import ItineraryCore

struct ResolvedPlace: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var subtitle: String = ""
    var latitude: Double
    var longitude: Double
    var countryCode: String

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    init(name: String, subtitle: String = "", coordinate: CLLocationCoordinate2D, countryCode: String) {
        self.name = name
        self.subtitle = subtitle
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.countryCode = countryCode.uppercased()
    }

    init(_ known: KnownPlace) {
        self.init(name: known.name, subtitle: CountryStore.shared.name(known.countryCode),
                  coordinate: known.coordinate, countryCode: known.countryCode)
    }
}

enum Geocoding {
    /// Looks up a typed place name (online). Prefers results near `near` if given.
    static func search(_ query: String, near: CLLocationCoordinate2D? = nil) async -> [ResolvedPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let near {
            request.region = MKCoordinateRegion(center: near, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
        }
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.map(resolved(from:))
    }

    static func resolve(_ completion: MKLocalSearchCompletion) async -> ResolvedPlace? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return nil }
        var place = resolved(from: item)
        if !completion.title.isEmpty { place.name = completion.title }
        return place
    }

    static func resolved(from item: MKMapItem) -> ResolvedPlace {
        let pm = item.placemark
        let name = item.name ?? pm.locality ?? pm.name ?? "Pinned place"
        let subtitle = [pm.locality, pm.administrativeArea, pm.country].compactMap { $0 }.filter { $0 != name }.joined(separator: ", ")
        return ResolvedPlace(name: name, subtitle: subtitle, coordinate: pm.coordinate, countryCode: pm.isoCountryCode ?? "")
    }

    /// Name + country for a tapped map point. Falls back to the nearest
    /// known place / country when offline.
    static func reverse(_ coordinate: CLLocationCoordinate2D) async -> ResolvedPlace {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let marks = try? await CLGeocoder().reverseGeocodeLocation(location), let pm = marks.first {
            let name = pm.locality ?? pm.subAdministrativeArea ?? pm.administrativeArea ?? pm.name ?? pm.country ?? "Pinned place"
            return ResolvedPlace(name: name, subtitle: pm.country ?? "", coordinate: coordinate, countryCode: pm.isoCountryCode ?? "")
        }
        let nearest = nearestKnown(to: coordinate)
        if let nearest, Geo.distanceKm(GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
                                       GeoPoint(latitude: nearest.latitude, longitude: nearest.longitude)) < 40 {
            return ResolvedPlace(name: nearest.name, subtitle: CountryStore.shared.name(nearest.countryCode),
                                 coordinate: coordinate, countryCode: nearest.countryCode)
        }
        return ResolvedPlace(name: "Pinned place", coordinate: coordinate, countryCode: nearest?.countryCode ?? "")
    }

    static func nearestKnown(to c: CLLocationCoordinate2D) -> KnownPlace? {
        let p = GeoPoint(latitude: c.latitude, longitude: c.longitude)
        return CountryStore.shared.places.min {
            Geo.distanceKm(p, GeoPoint(latitude: $0.latitude, longitude: $0.longitude)) <
                Geo.distanceKm(p, GeoPoint(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    /// Driving/transit time between two points, if Apple Maps can route it.
    static func travelTime(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: a))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: b))
        request.transportType = .automobile
        guard let eta = try? await MKDirections(request: request).calculateETA() else { return nil }
        return eta.expectedTravelTime
    }
}

/// Type-ahead place search: instant offline matches from the bundled list,
/// plus Apple Maps suggestions when online.
final class PlaceSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { update() }
    }
    @Published private(set) var local: [KnownPlace] = []
    @Published private(set) var completions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    private func update() {
        local = CountryStore.shared.search(query, limit: 8)
        if query.trimmingCharacters(in: .whitespaces).count >= 2 {
            completer.queryFragment = query
        } else {
            completions = []
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = Array(completer.results.prefix(10))
        DispatchQueue.main.async { self.completions = results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.completions = [] }
    }
}

/// Minimal "where am I" helper.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var lastLocation: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let loc = locations.last
        DispatchQueue.main.async { self.lastLocation = loc }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

extension CLLocationCoordinate2D {
    var geoPoint: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}
