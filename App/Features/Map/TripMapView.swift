import SwiftUI
import SwiftData
import MapKit
import ItineraryCore

struct TripMapView: View {
    @Bindable var trip: Trip
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStop: Stop?
    @State private var addMode = false
    @State private var pendingPlace: ResolvedPlace?
    @State private var showSearch = false
    @State private var showItems = true
    @State private var styleChoice = 0
    @State private var resolving = false

    private var stops: [Stop] { trip.orderedStops }

    private struct Segment: Identifiable {
        let id: Int
        let coords: [CLLocationCoordinate2D]
        let travelled: Bool
    }

    private var segments: [Segment] {
        let active = stops.filter { $0.status != .skipped }
        guard active.count > 1 else { return [] }
        return (1..<active.count).map { i in
            let a = active[i - 1], b = active[i]
            let travelled = b.status == .visited || b.status == .current
            return Segment(id: i, coords: [a.coordinate, b.coordinate], travelled: travelled)
        }
    }

    private var itemPins: [PlaceItem] {
        stops.flatMap(\.items).filter { $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    ForEach(segments) { seg in
                        if seg.travelled {
                            MapPolyline(coordinates: seg.coords)
                                .stroke(Theme.visited, lineWidth: 4)
                        } else {
                            MapPolyline(coordinates: seg.coords)
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))
                        }
                    }
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                            Button {
                                selectedStop = stop
                            } label: {
                                StopNumberBadge(number: index + 1, status: stop.status, size: stop.status == .current ? 36 : 28)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if showItems {
                        ForEach(itemPins) { item in
                            if let c = item.coordinate {
                                Marker(item.name, systemImage: item.kind.symbol, coordinate: c)
                                    .tint(Theme.color(for: item.kind.section))
                            }
                        }
                    }
                    UserAnnotation()
                }
                .mapStyle(mapStyle)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture(coordinateSpace: .local) { point in
                    guard addMode, let coordinate = proxy.convert(point, from: .local) else { return }
                    addMode = false
                    resolving = true
                    Task {
                        let place = await Geocoding.reverse(coordinate)
                        resolving = false
                        pendingPlace = place
                    }
                }
            }
            .overlay(alignment: .top) {
                if addMode {
                    Label("Tap anywhere on the map to add a stop", systemImage: "hand.tap.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                } else if resolving {
                    ProgressView("Finding place…")
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .safeAreaInset(edge: .bottom) {
                NextUpCard(trip: trip) { stop in selectedStop = stop }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle(trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { app.showMore = true } label: { Image(systemName: "line.3.horizontal.circle") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            withAnimation { position = .automatic }
                        } label: { Label("Whole route", systemImage: "arrow.up.left.and.arrow.down.right") }
                        if !trip.countryCodesInRoute.isEmpty {
                            Section("Zoom to country") {
                                ForEach(trip.countryCodesInRoute, id: \.self) { code in
                                    Button("\(CountryStore.shared.flag(code)) \(CountryStore.shared.name(code))") { zoom(toCountry: code) }
                                }
                            }
                        }
                        Section("Map style") {
                            Picker("Style", selection: $styleChoice) {
                                Text("Standard").tag(0)
                                Text("Satellite").tag(1)
                                Text("Hybrid").tag(2)
                            }
                        }
                        Toggle("Show saved places", isOn: $showItems)
                    } label: { Image(systemName: "map") }

                    Menu {
                        Button { showSearch = true } label: { Label("Search for a place", systemImage: "magnifyingglass") }
                        Button { addMode = true } label: { Label("Tap on the map", systemImage: "mappin.and.ellipse") }
                    } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(item: $selectedStop) { stop in
                NavigationStack { StopDetailView(stop: stop) }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $pendingPlace) { place in
                AddStopConfirmView(trip: trip, place: place) { stop in
                    focus(on: stop)
                }
            }
            .sheet(isPresented: $showSearch) {
                AddStopSearchView(trip: trip) { stop in focus(on: stop) }
            }
            .onChange(of: app.focusStopID) { _, id in
                guard let id, let stop = stops.first(where: { $0.id == id }) else { return }
                focus(on: stop)
                app.focusStopID = nil
            }
        }
    }

    private var mapStyle: MapStyle {
        switch styleChoice {
        case 1: return .imagery(elevation: .realistic)
        case 2: return .hybrid(elevation: .realistic)
        default: return .standard(elevation: .realistic)
        }
    }

    private func focus(on stop: Stop) {
        withAnimation(.easeInOut) {
            position = .region(MKCoordinateRegion(center: stop.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)))
        }
    }

    private func zoom(toCountry code: String) {
        let coords = stops.filter { $0.countryCode == code }.map(\.coordinate)
        if let region = MapMath.region(for: coords, minSpan: 2) {
            withAnimation(.easeInOut) { position = .region(region) }
        }
    }
}

/// Floating card: where you are now and what's next.
struct NextUpCard: View {
    let trip: Trip
    var onSelect: (Stop) -> Void

    var body: some View {
        let schedule = trip.schedule()
        let stops = trip.orderedStops
        Group {
            if stops.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading) {
                        Text("Start your route").font(.headline)
                        Text("Tap + to search for a place or drop a pin.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else if let cur = trip.currentStop {
                let next = trip.nextActiveStop(after: cur)
                Button { onSelect(cur) } label: {
                    HStack(spacing: 12) {
                        StopNumberBadge(number: (stops.firstIndex(where: { $0.id == cur.id }) ?? 0) + 1, status: .current, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You're in \(cur.name) \(CountryStore.shared.flag(cur.countryCode))").font(.headline)
                            if let next, let d = schedule[next.id] {
                                Label("Next: \(next.name) · \(Fmt.day.string(from: d.arrival))", systemImage: next.transportMode.symbol)
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Last stop of the trip!").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            } else if let first = stops.first(where: { $0.status == .planned }) {
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: trip.startDate)).day ?? 0
                Button { onSelect(first) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "airplane.departure").font(.title2).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(days > 0 ? "\(days) days to go!" : "Ready when you are").font(.headline)
                            Text("\(stops.count) stops · \(Fmt.nights(trip.totalNights)) · first stop \(first.name)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.visited)
                    Text("Trip complete - what a journey!").font(.headline)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}
