import SwiftUI
import SwiftData
import ItineraryCore

/// "Getting here" for a stop: the usual way backpackers do this leg, with your own overrides.
struct GettingHereSection: View {
    @Bindable var stop: Stop
    let previous: Stop
    let trip: Trip
    @EnvironmentObject private var rates: CurrencyService

    private var km: Double { Geo.distanceKm(previous.geoPoint, stop.geoPoint) }
    private var home: String { trip.homeCurrency }

    private var typical: LegEstimate {
        Costs.db.estimateLeg(from: previous.name, fromCountry: previous.countryCode, to: stop.name, toCountry: stop.countryCode,
                             distanceKm: km, style: trip.travelStyle)
    }

    var body: some View {
        let t = typical
        let mode = stop.transportModeIsAuto ? t.mode : stop.transportMode
        let typicalCostGBP = mode == t.mode ? t.cost : Costs.db.estimateLeg(mode: mode, distanceKm: km, country: stop.countryCode, style: trip.travelStyle)
        let typicalCost = rates.convert(typicalCostGBP, from: "GBP", to: home)
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: t.mode.symbol).font(.title3).foregroundStyle(.teal).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usually: \(t.mode.label)").font(.subheadline.weight(.semibold))
                        Text("~\(Fmt.hours(t.hours)) · about \(Fmt.money(rates.convert(t.cost, from: "GBP", to: home), home)) · \(Fmt.km(km))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !t.tip.isEmpty {
                    Text(t.tip).font(.caption).foregroundStyle(.secondary)
                }
                if !t.fromTable {
                    Text("Estimated from distance - not a route we have researched.").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Picker("How I'm going", selection: Binding(get: { mode }, set: { new in
                stop.transportMode = new
                stop.transportModeIsAuto = (new == t.mode)
            })) {
                ForEach(TransportMode.allCases) { m in Label(m.label, systemImage: m.symbol).tag(m) }
            }
            HStack {
                Text("Cost (\(home))")
                Spacer()
                TextField(Fmt.money(typicalCost, home), value: Binding(get: { stop.legCostOverride }, set: { stop.transportCostOverride = $0; stop.transportCost = 0 }),
                          format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
            if !stop.transportModeIsAuto || stop.legCostOverride != nil {
                Button("Use the typical way & price") {
                    stop.transportModeIsAuto = true
                    stop.transportMode = t.mode
                    stop.transportCostOverride = nil
                    stop.transportCost = 0
                }
            }
            TextField("Notes (e.g. 12Go sleeper bus, 8pm)", text: $stop.transportNotes, axis: .vertical)
            Menu {
                Link("12Go (buses, trains, ferries)", destination: search("12go \(previous.name) to \(stop.name)"))
                Link("Rome2Rio", destination: rome2rio)
                Link("Skyscanner flights", destination: search("skyscanner \(previous.name) to \(stop.name) flights"))
            } label: {
                Label("Check prices & times", systemImage: "safari")
            }
        } header: {
            Text("Getting here from \(previous.name)")
        } footer: {
            Text("Leave the cost empty to use the typical price in your budget.")
        }
    }

    private func search(_ q: String) -> URL {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: q)]
        return c.url!
    }

    private var rome2rio: URL {
        let a = previous.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? previous.name
        let b = stop.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stop.name
        return URL(string: "https://www.rome2rio.com/map/\(a)/\(b)") ?? URL(string: "https://www.rome2rio.com")!
    }
}

/// Pick a researched tour for this stop (or type any activity) - the price goes into the budget.
struct TourPickerView: View {
    let stop: Stop
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @State private var query = ""
    @State private var editing: PlaceItem?

    private var style: TravelStyle { stop.trip?.travelStyle ?? .budget }

    private var suggestions: [TourInfo] {
        let base = Costs.db.suggestedTours(place: stop.name, country: stop.countryCode)
        let q = PlaceName.normalize(query)
        guard !q.isEmpty else { return base }
        let all = Costs.db.tours.tours.filter { t in
            PlaceName.normalize(t.name).contains(q) || t.keywords.contains { PlaceName.normalize($0).contains(q) } || PlaceName.normalize(t.place).contains(q)
        }
        return all.sorted { a, b in
            let ah = PlaceName.matches(a.place, stop.name), bh = PlaceName.matches(b.place, stop.name)
            if ah != bh { return ah }
            return (a.country == stop.countryCode) && (b.country != stop.countryCode)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    let est = Costs.db.estimateActivity(name: query, place: stop.name, country: stop.countryCode, style: style)
                    Section {
                        Button { add(name: query, price: est.price, tour: est.tour) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add \"\(query)\"").foregroundStyle(.primary)
                                    Text(est.tour != nil ? "Matches \(est.tour!.name)" : "Typical price for: \(est.label)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("~\(Fmt.money(est.price, "GBP"))").bold()
                            }
                        }
                    } footer: {
                        Text("You can change the price after adding it.")
                    }
                }
                let list = suggestions
                let here = list.filter { PlaceName.matches($0.place, stop.name) }
                let more = list.filter { !PlaceName.matches($0.place, stop.name) }
                if !here.isEmpty {
                    Section("Popular in \(stop.name)") {
                        ForEach(here) { t in tourRow(t) }
                    }
                }
                if !more.isEmpty {
                    Section(query.isEmpty ? "Elsewhere in \(CountryStore.shared.name(stop.countryCode))" : "Other matches") {
                        ForEach(more.prefix(40)) { t in tourRow(t) }
                    }
                }
                if list.isEmpty && query.isEmpty {
                    Section {
                        Text("No researched tours for this area yet - type what you want to do above and I'll estimate a typical price.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "e.g. Ha Giang Loop, cooking class, diving")
            .navigationTitle("Add tour / activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editing) { item in
                PlaceItemEditor(stop: stop, item: item, section: item.kind.section)
            }
        }
    }

    private func tourRow(_ t: TourInfo) -> some View {
        let added = stop.items.contains { $0.name == t.name }
        return Button {
            add(name: t.name, price: t.price(style), tour: t)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: t.kind == "ticket" ? "ticket.fill" : "figure.hiking")
                    .foregroundStyle(.green).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.name).foregroundStyle(.primary)
                    Text("\(t.place) · \(t.duration)").font(.caption).foregroundStyle(.secondary)
                    if !t.notes.isEmpty {
                        Text(t.notes).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(t.price(style) == 0 ? "Free" : "~\(Fmt.money(t.price(style), "GBP"))").bold()
                    if added {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Image(systemName: "plus.circle").foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Link("Search GetYourGuide", destination: TourLinks.getYourGuide(t.name))
            Link("Search Klook", destination: TourLinks.klook(t.name))
            Link("Search Google", destination: TourLinks.google("\(t.name) price"))
        }
    }

    private func add(name: String, price: Double, tour: TourInfo?) {
        let kind: PlaceKind = tour?.kind == "ticket" ? .activity : .tour
        let item = PlaceItem(kind: kind, name: name.trimmingCharacters(in: .whitespaces), price: price, currency: "GBP", notes: tour?.notes ?? "")
        item.priceIsEstimate = true
        item.stop = stop
        context.insert(item)
        try? context.save()
        app.flash("Added \(name) · ~\(Fmt.money(price, "GBP"))")
        query = ""
    }
}

enum TourLinks {
    static func google(_ q: String) -> URL {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: q)]
        return c.url!
    }

    static func getYourGuide(_ q: String) -> URL {
        var c = URLComponents(string: "https://www.getyourguide.com/s/")!
        c.queryItems = [URLQueryItem(name: "q", value: q)]
        return c.url!
    }

    static func klook(_ q: String) -> URL {
        var c = URLComponents(string: "https://www.klook.com/en-GB/search/result/")!
        c.queryItems = [URLQueryItem(name: "query", value: q)]
        return c.url!
    }

    static func hostelworld(_ place: String) -> URL { google("hostelworld \(place) hostels") }
    static func booking(_ place: String) -> URL { google("booking.com \(place) hostel") }
}
