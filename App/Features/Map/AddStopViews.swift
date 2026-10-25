import SwiftUI
import SwiftData
import MapKit
import ItineraryCore

/// Search for a place (offline list + Apple Maps) and add it to the route.
struct AddStopSearchView: View {
    let trip: Trip
    var insertAfter: Stop?
    var onAdded: (Stop) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = PlaceSearchModel()
    @State private var chosen: ResolvedPlace?
    @State private var resolving = false

    var body: some View {
        NavigationStack {
            List {
                if search.query.isEmpty {
                    Section("Popular with backpackers") {
                        ForEach(popular) { p in placeRow(ResolvedPlace(p)) }
                    }
                }
                if !search.local.isEmpty {
                    Section("Suggestions (works offline)") {
                        ForEach(search.local) { p in placeRow(ResolvedPlace(p)) }
                    }
                }
                if !search.completions.isEmpty {
                    Section("Apple Maps") {
                        ForEach(search.completions, id: \.self) { c in
                            Button {
                                resolving = true
                                Task {
                                    let r = await Geocoding.resolve(c)
                                    resolving = false
                                    chosen = r
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(c.title).foregroundStyle(.primary)
                                    if !c.subtitle.isEmpty { Text(c.subtitle).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
            .overlay { if resolving { ProgressView().padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City, island, hostel, landmark…")
            .navigationTitle("Add a stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(item: $chosen) { place in
                AddStopConfirmView(trip: trip, place: place, insertAfter: insertAfter) { stop in
                    onAdded(stop)
                    dismiss()
                }
            }
        }
    }

    private var popular: [KnownPlace] {
        let names = ["Bangkok", "Bali", "Hanoi", "Sydney", "Cusco", "Lisbon", "Medellin", "Queenstown", "Tokyo", "Cape Town"]
        return names.compactMap { n in CountryStore.shared.places.first { $0.name == n } }
    }

    private func placeRow(_ place: ResolvedPlace) -> some View {
        Button { chosen = place } label: {
            HStack {
                Text(CountryStore.shared.flag(place.countryCode)).font(.title3)
                VStack(alignment: .leading) {
                    Text(place.name).foregroundStyle(.primary)
                    Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Confirm name, nights and position before adding a stop.
struct AddStopConfirmView: View {
    let trip: Trip
    let place: ResolvedPlace
    var insertAfter: Stop?
    var onAdded: (Stop) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var nights = 3
    @State private var positionIndex = -1   // -1 = end
    @State private var countryCode = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)))) {
                        Marker(name.isEmpty ? place.name : name, coordinate: place.coordinate).tint(Theme.accent)
                    }
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    .allowsHitTesting(false)
                }
                Section("Place") {
                    TextField("Name", text: $name)
                    Picker("Country", selection: $countryCode) {
                        Text("Unknown").tag("")
                        ForEach(CountryStore.shared.countries) { c in
                            Text("\(c.flag) \(c.name)").tag(c.code)
                        }
                    }
                }
                Section("Plan") {
                    Stepper(value: $nights, in: 0...120) {
                        HStack {
                            Text("Stay")
                            Spacer()
                            Text(Fmt.nights(nights)).foregroundStyle(.secondary)
                        }
                    }
                    Picker("Position", selection: $positionIndex) {
                        Text("End of route").tag(-1)
                        ForEach(Array(trip.orderedStops.enumerated()), id: \.element.id) { i, s in
                            Text("After \(i + 1). \(s.name)").tag(i + 1)
                        }
                        if !trip.orderedStops.isEmpty { Text("Start of route").tag(0) }
                    }
                }
                if let info = CountryStore.shared.country(countryCode), let usd = info.dailyCostUSD {
                    Section {
                        Label("Backpackers spend about $\(Int(usd))/day in \(info.name)", systemImage: "sterlingsign.circle")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        var p = place
                        p.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? place.name : name
                        p.countryCode = countryCode
                        let stop = trip.addStop(p, nights: nights, at: positionIndex < 0 ? nil : positionIndex, context: context)
                        onAdded(stop)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                name = place.name
                countryCode = place.countryCode
                if let after = insertAfter, let i = trip.orderedStops.firstIndex(where: { $0.id == after.id }) {
                    positionIndex = i + 1
                }
            }
        }
    }
}
