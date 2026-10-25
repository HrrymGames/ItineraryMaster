import SwiftUI
import SwiftData
import ItineraryCore

struct CountryListView: View {
    @Query(sort: \Trip.createdAt) private var trips: [Trip]
    @State private var query = ""

    private var routeCodes: [String] { trips.first?.countryCodesInRoute ?? [] }

    private var filtered: [CountryInfo] {
        let all = CountryStore.shared.countries
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) || $0.capital.lowercased().contains(q) || $0.code.lowercased() == q }
    }

    private var regions: [String] {
        Array(Set(filtered.map { $0.region.isEmpty ? "Other" : $0.region })).sorted()
    }

    var body: some View {
        List {
            if query.isEmpty && !routeCodes.isEmpty {
                Section("On your route") {
                    ForEach(routeCodes, id: \.self) { code in
                        if let c = CountryStore.shared.country(code) {
                            NavigationLink { CountryDetailView(code: code) } label: { CountryRow(country: c) }
                        }
                    }
                }
            }
            ForEach(regions, id: \.self) { region in
                Section(region) {
                    ForEach(filtered.filter { ($0.region.isEmpty ? "Other" : $0.region) == region }) { c in
                        NavigationLink { CountryDetailView(code: c.code) } label: { CountryRow(country: c) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search countries")
        .navigationTitle("Countries")
    }
}

struct CountryRow: View {
    let country: CountryInfo
    var body: some View {
        HStack(spacing: 12) {
            Text(country.flag).font(.title2)
            VStack(alignment: .leading) {
                Text(country.name)
                Text([country.capital, country.mainCurrency].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let usd = country.dailyCostUSD {
                Text("$\(Int(usd))/day").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct CountryDetailView: View {
    let code: String

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var rates: CurrencyService
    @Query(sort: \Trip.createdAt) private var trips: [Trip]
    @Query private var notes: [CountryNote]
    @Query(sort: \SavedVideo.savedAt, order: .reverse) private var videos: [SavedVideo]
    @State private var addPlace: ResolvedPlace?
    @State private var openVideo: SavedVideo?

    private var info: CountryInfo? { CountryStore.shared.country(code) }
    private var trip: Trip? { trips.first }
    private var note: CountryNote? { notes.first { $0.countryCode == code } }
    private var home: String { trip?.homeCurrency ?? "GBP" }
    private var stopsHere: [Stop] { trip?.orderedStops.filter { $0.countryCode == code } ?? [] }
    private var videosHere: [SavedVideo] { videos.filter { $0.countryCodes.contains(code) || $0.stop?.countryCode == code } }

    var body: some View {
        if let info {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text(info.flag).font(.system(size: 72))
                        Text(info.name).font(.title.bold())
                        if info.officialName != info.name {
                            Text(info.officialName).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        Text([info.subregion, info.region].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Your plan") {
                    if stopsHere.isEmpty {
                        Button {
                            let capital = CountryStore.shared.places.first { $0.countryCode == code && $0.name == info.capital }
                            addPlace = capital.map(ResolvedPlace.init) ?? ResolvedPlace(name: info.capital.isEmpty ? info.name : info.capital, coordinate: info.coordinate, countryCode: code)
                        } label: {
                            Label("Add \(info.name) to my route", systemImage: "plus.circle.fill")
                        }
                    } else {
                        ForEach(stopsHere) { s in
                            NavigationLink { StopDetailView(stop: s) } label: {
                                HStack {
                                    Text(s.name)
                                    Spacer()
                                    Text(Fmt.nights(s.nights)).foregroundStyle(.secondary)
                                }
                            }
                        }
                        let nights = stopsHere.filter { $0.status != .skipped }.reduce(0) { $0 + $1.nights }
                        LabeledContent("Total", value: Fmt.nights(nights))
                        LabeledContent("Planned spend", value: Fmt.money(Double(nights) * dailyRate, home))
                    }
                    HStack {
                        Text("Daily budget (\(home))")
                        Spacer()
                        TextField("", value: Binding(get: { dailyRate }, set: { setDailyRate($0) }), format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                    }
                    if note?.dailyRate != nil {
                        Button("Reset to typical backpacker cost") { note?.dailyRate = nil }
                            .font(.caption)
                    }
                }

                Section("Quick facts") {
                    if !info.capital.isEmpty { fact("Capital", info.capital, "building.columns") }
                    ForEach(info.currencies, id: \.code) { cur in
                        let r = rates.convert(1, from: home, to: cur.code)
                        fact("Currency", "\(cur.name) (\(cur.code)) \(cur.symbol)\n1 \(home) ≈ \(formatRate(r)) \(cur.code)", "banknote")
                    }
                    if !info.languages.isEmpty { fact("Languages", info.languages.joined(separator: ", "), "character.bubble") }
                    if !info.plugs.isEmpty { fact("Plug types", info.plugs, "powerplug") }
                    fact("Drives on the", info.drivingSide, "car")
                    if !info.callingCode.isEmpty { fact("Calling code", info.callingCode, "phone") }
                    if !info.emergency.isEmpty { fact("Emergency", info.emergency, "cross.case.fill", tint: .red) }
                    if let usd = info.dailyCostUSD { fact("Backpacker budget", "≈ $\(Int(usd)) / day (\(Fmt.money(rates.convert(usd, from: "USD", to: home), home)))", "chart.bar") }
                    if !info.tipping.isEmpty { fact("Tipping", info.tipping, "hand.thumbsup") }
                    if !info.bestTime.isEmpty { fact("Best time to go", info.bestTime, "sun.max") }
                    if info.landlocked { fact("Geography", "Landlocked", "mountain.2") }
                }

                Section {
                    Link(destination: info.entryRequirementsURL) { Label("Visa & entry requirements (GOV.UK)", systemImage: "doc.text.fill") }
                    Link(destination: info.travelAdviceURL) { Label("Travel advice & safety (GOV.UK)", systemImage: "exclamationmark.shield.fill") }
                    Link(destination: info.wikipediaURL) { Label("Wikipedia", systemImage: "book.fill") }
                    Link(destination: tiktokURL(info.name)) { Label("TikTok: \(info.name) travel", systemImage: "play.square.fill") }
                } header: {
                    Text("Check before you go")
                } footer: {
                    Text("Visa rules change - always check the official advice for your passport before booking.")
                }

                if !videosHere.isEmpty {
                    Section("Saved videos (\(videosHere.count))") {
                        ForEach(videosHere) { v in
                            Button { openVideo = v } label: { VideoRow(video: v) }.buttonStyle(.plain)
                        }
                    }
                }

                Section("My notes") {
                    TextField("Visa notes, SIM card, phrases, scams to avoid…", text: Binding(get: { note?.notes ?? "" }, set: { ensureNote().notes = $0 }), axis: .vertical)
                        .lineLimit(3...15)
                }

                if !info.borders.isEmpty {
                    Section("Neighbours") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(neighbours, id: \.code) { n in
                                    NavigationLink { CountryDetailView(code: n.code) } label: {
                                        ChipView(title: "\(n.flag) \(n.name)", color: .secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(info.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $addPlace) { p in
                if let trip { AddStopConfirmView(trip: trip, place: p) }
            }
            .sheet(item: $openVideo) { v in
                NavigationStack { VideoDetailView(video: v, trip: trip) }
            }
        } else {
            ContentUnavailableView("Unknown country", systemImage: "questionmark.circle")
        }
    }

    private var neighbours: [CountryInfo] {
        (info?.borders ?? []).compactMap { CountryStore.shared.country(alpha3: $0) }
    }

    private var dailyRate: Double {
        if let r = note?.dailyRate { return r }
        return CountryStore.shared.defaultDailyRate(for: code, in: home, rates: rates.rates).rounded()
    }

    private func setDailyRate(_ v: Double) {
        ensureNote().dailyRate = v
    }

    private func ensureNote() -> CountryNote {
        if let note { return note }
        let n = CountryNote(countryCode: code)
        context.insert(n)
        return n
    }

    private func fact(_ title: String, _ value: String, _ symbol: String, tint: Color = Theme.accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline)
            }
        }
    }

    private func formatRate(_ r: Double) -> String {
        if r >= 100 { return String(format: "%.0f", r) }
        if r >= 1 { return String(format: "%.2f", r) }
        return String(format: "%.4f", r)
    }

    private func tiktokURL(_ name: String) -> URL {
        var c = URLComponents(string: "https://www.tiktok.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: "\(name) travel")]
        return c.url!
    }
}
