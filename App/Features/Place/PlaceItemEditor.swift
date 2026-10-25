import SwiftUI
import SwiftData
import MapKit
import ItineraryCore

/// Add or edit a hostel / volunteering gig / activity etc. for a stop.
struct PlaceItemEditor: View {
    let stop: Stop
    let item: PlaceItem?
    let section: PlaceSection

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var kind: PlaceKind = .activity
    @State private var name = ""
    @State private var url = ""
    @State private var price: Double = 0
    @State private var currency = "GBP"
    @State private var notes = ""
    @State private var rating = 0
    @State private var isBooked = false
    @State private var nights: Int = 1
    @State private var wholeStop = true
    /// The typical price we filled in (so we can tell if the user changed it).
    @State private var estimatedPrice: Double?
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var searchResults: [ResolvedPlace] = []
    @State private var searching = false

    private var kinds: [PlaceKind] {
        let inSection = PlaceKind.allCases.filter { $0.section == section }
        return inSection + PlaceKind.allCases.filter { $0.section != section }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(kinds) { k in Label(k.label, systemImage: k.symbol).tag(k) }
                    }
                    TextField("Name (e.g. Mad Monkey Hostel)", text: $name)
                    TextField("Link (Hostelworld, Worldpackers, TikTok…)", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    AmountField(title: kind == .hostel ? "Price per night" : "Price", amount: $price, currency: $currency)
                    if kind == .hostel {
                        Toggle("Staying the whole stop (\(Fmt.nights(stop.nights)))", isOn: $wholeStop)
                        if !wholeStop {
                            Stepper("Nights here: \(nights)", value: $nights, in: 1...max(1, stop.nights))
                        }
                        let n = wholeStop ? stop.nights : nights
                        LabeledContent("Total", value: "\(Fmt.money(price, currency)) × \(n) = \(Fmt.money(price * Double(n), currency))")
                        Button("Use typical price for \(stop.name)") { fillTypicalHostelPrice() }
                            .font(.caption)
                    } else if kind.section == .todo, !name.isEmpty {
                        Button("Estimate typical price") {
                            let est = Costs.db.estimateActivity(name: name, place: stop.name, country: stop.countryCode, style: stop.trip?.travelStyle ?? .budget)
                            price = est.price
                            currency = "GBP"
                            estimatedPrice = est.price
                        }
                        .font(.caption)
                    }
                    Toggle(kind == .hostel ? "Booked" : (kind.section == .work ? "Confirmed" : "Booked / done"), isOn: $isBooked)
                    Menu {
                        if kind == .hostel {
                            Link("Hostelworld", destination: TourLinks.hostelworld(stop.name))
                            Link("Booking.com", destination: TourLinks.booking(stop.name))
                        } else {
                            Link("GetYourGuide", destination: TourLinks.getYourGuide(name.isEmpty ? stop.name : name))
                            Link("Klook", destination: TourLinks.klook(name.isEmpty ? stop.name : name))
                        }
                        Link("Google", destination: TourLinks.google("\(name) \(stop.name) price"))
                    } label: {
                        Label("Search current price", systemImage: "safari")
                    }
                } header: {
                    Text("Cost")
                } footer: {
                    Text(kind == .hostel
                         ? "Booked stays count first in your budget; otherwise the average of your saved hostels here is used."
                         : "Every priced activity counts towards your budget.")
                }
                Section("Rating") {
                    StarRating(rating: $rating)
                }
                Section("Notes") {
                    TextField("Details, dates, contact, what to bring…", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section {
                    if let lat = latitude, let lon = longitude {
                        let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Map(initialPosition: .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))) {
                            Marker(name, systemImage: kind.symbol, coordinate: c).tint(Theme.color(for: kind.section))
                        }
                        .frame(height: 140)
                        .allowsHitTesting(false)
                        Button("Remove location", role: .destructive) { latitude = nil; longitude = nil }
                    }
                    Button {
                        Task { await findOnMap() }
                    } label: {
                        HStack {
                            Label("Find \"\(name.isEmpty ? "place" : name)\" on the map", systemImage: "mappin.and.ellipse")
                            if searching { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    ForEach(searchResults) { r in
                        Button {
                            latitude = r.latitude
                            longitude = r.longitude
                            searchResults = []
                        } label: {
                            VStack(alignment: .leading) {
                                Text(r.name)
                                Text(r.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Places with a location show as pins on the map.")
                }
            }
            .navigationTitle(item == nil ? "Add to \(stop.name)" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        currency = CountryStore.shared.country(stop.countryCode)?.mainCurrency ?? stop.trip?.homeCurrency ?? "GBP"
        if let item {
            kind = item.kind
            name = item.name
            url = item.url
            price = item.price
            currency = item.currency
            notes = item.notes
            rating = item.rating
            isBooked = item.isBooked
            latitude = item.latitude
            longitude = item.longitude
            nights = item.nights ?? stop.nights
            wholeStop = item.nights == nil
            estimatedPrice = item.priceIsEstimate ? item.price : nil
        } else {
            kind = section.defaultKind
            nights = max(1, stop.nights)
            if kind == .hostel { fillTypicalHostelPrice() }
        }
    }

    private func fillTypicalHostelPrice() {
        let style = stop.trip?.travelStyle ?? .budget
        price = Costs.db.typicalNightly(place: stop.name, country: stop.countryCode, style: style).price
        currency = "GBP"
        estimatedPrice = price
    }

    private func save() {
        let target: PlaceItem
        if let item {
            target = item
        } else {
            target = PlaceItem(kind: kind, name: name)
            target.stop = stop
            context.insert(target)
        }
        target.kind = kind
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        target.price = price
        target.currency = currency
        target.notes = notes
        target.rating = rating
        target.isBooked = isBooked
        target.nights = (kind == .hostel && !wholeStop) ? nights : nil
        target.priceIsEstimate = estimatedPrice != nil && estimatedPrice == price
        target.latitude = latitude
        target.longitude = longitude
        try? context.save()
        dismiss()
    }

    @MainActor
    private func findOnMap() async {
        searching = true
        defer { searching = false }
        searchResults = Array(await Geocoding.search("\(name) \(stop.name)", near: stop.coordinate).prefix(5))
        if searchResults.isEmpty {
            searchResults = Array(await Geocoding.search(name, near: stop.coordinate).prefix(5))
        }
    }
}
