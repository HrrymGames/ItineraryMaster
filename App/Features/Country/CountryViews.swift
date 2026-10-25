import SwiftUI
import SwiftData
import Charts
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

enum CountryTab: String, CaseIterable, Identifiable {
    case videos, rules, money, stops, facts
    var id: String { rawValue }
    var label: String {
        switch self {
        case .videos: return "Videos"
        case .rules: return "Rules"
        case .money: return "Money"
        case .stops: return "Stops"
        case .facts: return "Facts"
        }
    }
}

struct CountryDetailView: View {
    let code: String
    var initialTab: CountryTab = .videos

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var rates: CurrencyService
    @Query(sort: \Trip.createdAt) private var trips: [Trip]
    @Query private var notes: [CountryNote]
    @Query(sort: \SavedVideo.savedAt, order: .reverse) private var videos: [SavedVideo]
    @State private var addPlace: ResolvedPlace?
    @State private var openVideo: SavedVideo?
    @State private var tab: CountryTab = .videos
    @State private var folderFilter: VideoFolder?
    @State private var didSetTab = false

    private var info: CountryInfo? { CountryStore.shared.country(code) }
    private var sea: CountryCostInfo? { Costs.db.countries[code] }
    private var trip: Trip? { trips.first }
    private var note: CountryNote? { notes.first { $0.countryCode == code } }
    private var home: String { trip?.homeCurrency ?? "GBP" }
    private var style: TravelStyle { trip?.travelStyle ?? .budget }
    private var stopsHere: [Stop] { trip?.orderedStops.filter { $0.countryCode == code } ?? [] }
    private var videosHere: [SavedVideo] { videos.filter { $0.countryCodes.contains(code) || $0.stop?.countryCode == code } }

    var body: some View {
        if let info {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(info.flag).font(.system(size: 54))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name).font(.title2.bold())
                            Text([info.subregion, info.region].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(.secondary)
                            let nights = stopsHere.filter { $0.status != .skipped }.reduce(0) { $0 + $1.nights }
                            if nights > 0 {
                                Text("In your route: \(Fmt.nights(nights))").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    Picker("", selection: $tab) {
                        ForEach(CountryTab.allCases) { t in Text(t.label).tag(t) }
                    }
                    .pickerStyle(.segmented)
                }

                switch tab {
                case .videos: videosTab()
                case .rules: rulesTab(info)
                case .money: moneyTab(info)
                case .stops: stopsTab(info)
                case .facts: factsTab(info)
                }
            }
            .navigationTitle(info.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !didSetTab { tab = initialTab; didSetTab = true }
            }
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

    // MARK: Videos

    @ViewBuilder
    private func videosTab() -> some View {
        let all = videosHere
        let shown = folderFilter.map { f in all.filter { $0.folder == f } } ?? all
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { folderFilter = nil } label: { ChipView(title: "All \(all.count)", selected: folderFilter == nil) }
                    ForEach(VideoFolder.allCases) { f in
                        let n = all.filter { $0.folder == f }.count
                        if n > 0 {
                            Button { folderFilter = folderFilter == f ? nil : f } label: {
                                ChipView(title: "\(f.label) \(n)", symbol: f.symbol, color: Theme.color(for: f), selected: folderFilter == f)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if all.isEmpty {
                Text("Videos that mention \(CountryStore.shared.name(code)) land here automatically when you save them.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(shown) { v in
                Button { openVideo = v } label: { VideoRow(video: v) }.buttonStyle(.plain)
            }
        }
    }

    // MARK: Rules

    @ViewBuilder
    private func rulesTab(_ info: CountryInfo) -> some View {
        if let sea {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Visa (UK passport)", systemImage: "person.text.rectangle.fill").font(.headline)
                    Text(sea.visa.summary).font(.subheadline)
                    Text(sea.visa.how).font(.caption).foregroundStyle(.secondary)
                    if !sea.visa.longerStayNote.isEmpty {
                        Text(sea.visa.longerStayNote).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            ForEach(sea.rules) { section in
                Section {
                    ForEach(section.points, id: \.self) { p in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").bold().foregroundStyle(Theme.accent)
                            Text(p).font(.subheadline)
                        }
                    }
                } header: {
                    Label(section.title, systemImage: section.symbol)
                }
            }
            Section {
                Link(destination: info.entryRequirementsURL) { Label("Official entry requirements (GOV.UK)", systemImage: "doc.text.fill") }
                Link(destination: info.travelAdviceURL) { Label("Safety & travel advice (GOV.UK)", systemImage: "exclamationmark.shield.fill") }
            } footer: {
                Text("Checked \(sea.checked). Rules change - always confirm on GOV.UK before you travel.")
            }
        } else {
            Section {
                Text("Detailed rules are researched for South-East Asia countries. For \(info.name), check the official advice:")
                    .font(.callout)
                Link(destination: info.entryRequirementsURL) { Label("Entry requirements (GOV.UK)", systemImage: "doc.text.fill") }
                Link(destination: info.travelAdviceURL) { Label("Travel advice & laws (GOV.UK)", systemImage: "exclamationmark.shield.fill") }
            }
        }
        Section("My notes") {
            TextField("Things to remember: forms, laws, scams…", text: Binding(get: { note?.notes ?? "" }, set: { ensureNote().notes = $0 }), axis: .vertical)
                .lineLimit(3...15)
        }
    }

    // MARK: Money

    @ViewBuilder
    private func moneyTab(_ info: CountryInfo) -> some View {
        let daily = Costs.db.dailyCosts(country: code, style: style)
        let bed = Costs.db.typicalNightly(place: info.capital, country: code, style: style).price
        let bedCountry = sea?.accommodation.price(style) ?? bed
        let rows: [(String, String, Double, Color)] = [
            (style == .budget ? "Dorm bed" : "Private room", "bed.double.fill", bedCountry, .indigo),
            ("Food & drink", "fork.knife", daily.food, .orange),
            ("Getting around", "bus.fill", daily.localTransport, .cyan),
            ("Activities & entry fees", "figure.hiking", daily.activities, .green),
            ("Necessities, SIM, laundry", "basket.fill", daily.necessities, .mint),
            ("Nights out & other", "sparkles", daily.other, .purple),
        ]
        let total = rows.reduce(0) { $0 + $1.2 }
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("A typical day (\(style.shortLabel.lowercased()))").font(.caption).foregroundStyle(.secondary)
                Text(Fmt.money(rates.convert(total, from: "GBP", to: home), home))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if let sea { Text(sea.spendNote).font(.caption).foregroundStyle(.secondary) }
            }
            .padding(.vertical, 4)
            Chart(rows, id: \.0) { r in
                BarMark(x: .value("GBP", rates.convert(r.2, from: "GBP", to: home)), y: .value("What", r.0))
                    .foregroundStyle(r.3)
                    .annotation(position: .trailing) {
                        Text(Fmt.money(rates.convert(r.2, from: "GBP", to: home), home)).font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis(.hidden)
            .frame(height: 220)
        } header: {
            Text("What backpackers spend per day")
        } footer: {
            Text(sea != nil ? "Researched SEA backpacker figures, checked \(sea!.checked). Switch Budget/Flashpacker on the Budget tab." : "Rough estimate - this country isn't in the researched set.")
        }

        if let sea {
            Section("Entry costs") {
                LabeledContent("Visa (UK passport)", value: sea.visa.cost == 0 ? "Free (up to \(sea.visa.freeDays) days)" : Fmt.money(rates.convert(sea.visa.cost, from: "GBP", to: home), home))
                ForEach(sea.entryFees, id: \.name) { f in
                    LabeledContent(f.name, value: Fmt.money(rates.convert(f.cost, from: "GBP", to: home), home))
                }
            }
        }

        if let trip, !stopsHere.isEmpty {
            let plan = BudgetSync.plan(for: trip, rates: rates.rates)
            let mine = plan.stops.filter { $0.country == code }
            Section("Your plan here") {
                ForEach(mine) { p in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(p.name)
                            Text(Fmt.nights(p.nights)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.money(p.total, home))
                    }
                }
                LabeledContent("Total incl. visas & fees", value: Fmt.money(plan.byCountry[code] ?? 0, home))
            }
        }

        Section("Currency") {
            ForEach(info.currencies, id: \.code) { cur in
                let r = rates.convert(1, from: home, to: cur.code)
                LabeledContent("\(cur.name) (\(cur.symbol))", value: "1 \(home) ≈ \(formatRate(r)) \(cur.code)")
            }
        }
    }

    // MARK: Stops

    @ViewBuilder
    private func stopsTab(_ info: CountryInfo) -> some View {
        let schedule = trip?.schedule() ?? [:]
        Section {
            if stopsHere.isEmpty {
                Text("No stops in \(info.name) yet.").foregroundStyle(.secondary)
            }
            ForEach(stopsHere) { s in
                NavigationLink { StopDetailView(stop: s) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).strikethrough(s.status == .skipped)
                            Text(s.status == .skipped ? "Skipped" : "\(Fmt.range(schedule[s.id])) · \(Fmt.nights(s.nights))")
                                .font(.caption).foregroundStyle(.secondary)
                            let tours = s.items.filter { $0.kind.section == .todo }.count
                            let beds = s.items.filter { $0.kind == .hostel }.count
                            if tours + beds > 0 {
                                Text("\(beds) stay\(beds == 1 ? "" : "s") · \(tours) tour\(tours == 1 ? "" : "s")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if s.status == .current {
                            Text("NOW").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Theme.current, in: Capsule()).foregroundStyle(.white)
                        }
                    }
                }
            }
            Button {
                let capital = CountryStore.shared.places.first { $0.countryCode == code && $0.name == info.capital }
                addPlace = capital.map(ResolvedPlace.init) ?? ResolvedPlace(name: info.capital.isEmpty ? info.name : info.capital, coordinate: info.coordinate, countryCode: code)
            } label: {
                Label(stopsHere.isEmpty ? "Add \(info.name) to my route" : "Add another stop in \(info.name)", systemImage: "plus.circle.fill")
            }
        } header: {
            let nights = stopsHere.filter { $0.status != .skipped }.reduce(0) { $0 + $1.nights }
            Text(nights > 0 ? "Your stops · \(DurationFormat.summary(nights))" : "Your stops")
        }
    }

    // MARK: Facts

    @ViewBuilder
    private func factsTab(_ info: CountryInfo) -> some View {
        Section("Quick facts") {
            if !info.capital.isEmpty { fact("Capital", info.capital, "building.columns") }
            if !info.languages.isEmpty { fact("Languages", info.languages.joined(separator: ", "), "character.bubble") }
            if !info.plugs.isEmpty { fact("Plug types", info.plugs, "powerplug") }
            fact("Drives on the", info.drivingSide, "car")
            if !info.callingCode.isEmpty { fact("Calling code", info.callingCode, "phone") }
            if !info.emergency.isEmpty { fact("Emergency", info.emergency, "cross.case.fill", tint: .red) }
            if !info.tipping.isEmpty { fact("Tipping", info.tipping, "hand.thumbsup") }
            if !info.bestTime.isEmpty { fact("Best time to go", info.bestTime, "sun.max") }
            if info.landlocked { fact("Geography", "Landlocked", "mountain.2") }
        }
        Section {
            Link(destination: info.wikipediaURL) { Label("Wikipedia", systemImage: "book.fill") }
            Link(destination: tiktokURL(info.name)) { Label("TikTok: \(info.name) travel", systemImage: "play.square.fill") }
        }
        if !info.borders.isEmpty {
            Section("Neighbours") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(neighbours, id: \.code) { n in
                            NavigationLink { CountryDetailView(code: n.code, initialTab: .facts) } label: {
                                ChipView(title: "\(n.flag) \(n.name)", color: .secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var neighbours: [CountryInfo] {
        (info?.borders ?? []).compactMap { CountryStore.shared.country(alpha3: $0) }
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
