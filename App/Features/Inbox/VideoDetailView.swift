import SwiftUI
import SwiftData
import ItineraryCore

struct VideoDetailView: View {
    @Bindable var video: SavedVideo
    let trip: Trip?

    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PackingList.order) private var packingLists: [PackingList]

    @State private var addPlace: ResolvedPlace?
    @State private var editingCaption = false
    @State private var draftCaption = ""
    @State private var working = false
    @State private var confirmDelete = false

    private var stops: [Stop] { trip?.orderedStops ?? [] }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    ThumbnailView(data: video.thumbnail)
                        .frame(width: 120, height: 165)
                        .onTapGesture { video.url?.openExternally() }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.displayTitle).font(.headline)
                        if !video.author.isEmpty { Text("@\(video.author)").font(.subheadline).foregroundStyle(.secondary) }
                        Text("Saved \(Fmt.dayYear.string(from: video.savedAt))").font(.caption).foregroundStyle(.secondary)
                        Button {
                            video.url?.openExternally()
                        } label: {
                            Label("Open in \(video.source)", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        HStack {
                            Button { video.isFavourite.toggle() } label: {
                                Image(systemName: video.isFavourite ? "heart.fill" : "heart").foregroundStyle(.pink)
                            }
                            ShareLink(item: video.urlString) { Image(systemName: "square.and.arrow.up") }
                        }
                        .buttonStyle(.borderless)
                        .font(.title3)
                    }
                }
                .padding(.vertical, 4)
                if video.fetchState == .pending || working {
                    HStack { ProgressView(); Text("Getting caption & thumbnail…").foregroundStyle(.secondary) }
                } else if video.fetchState == .failed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(video.fetchError ?? "Couldn't get the details.",
                              systemImage: video.fetchErrorIsTemporary ? "wifi.exclamationmark" : "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        HStack {
                            Button("Try again") { Task { await refetch() } }.buttonStyle(.bordered)
                            Button("Type caption") { draftCaption = video.caption; editingCaption = true }.buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Category") {
                FlowLayout(spacing: 8) {
                    ForEach(VideoCategory.allCases) { c in
                        let on = video.categories.contains(c)
                        Button {
                            var cats = video.categories
                            if on { cats.removeAll { $0 == c } } else { cats.append(c) }
                            video.categories = cats
                        } label: {
                            ChipView(title: c.label, symbol: c.symbol, color: Theme.color(for: c), selected: on)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Linked to stop", selection: Binding(get: { video.stop?.id }, set: { id in
                    video.stop = stops.first { $0.id == id }
                    if video.stop != nil { video.isSorted = true }
                })) {
                    Text("Not linked").tag(UUID?.none)
                    ForEach(stops) { s in Text("\(CountryStore.shared.flag(s.countryCode)) \(s.name)").tag(UUID?.some(s.id)) }
                }
                Toggle("Sorted", isOn: $video.isSorted)
                if let stop = video.stop {
                    Menu {
                        ForEach(PlaceKind.allCases) { k in
                            Button { addAsItem(kind: k, to: stop) } label: { Label(k.label, systemImage: k.symbol) }
                        }
                    } label: {
                        Label("Save as a place in \(stop.name)…", systemImage: "plus.square.on.square")
                    }
                }
            } header: {
                Text("Organise")
            } footer: {
                Text("Linking a video to a stop shows it on that place's page.")
            }

            if !detectedPlaces.isEmpty || !video.countryCodes.isEmpty {
                Section("Places mentioned") {
                    ForEach(video.countryCodes, id: \.self) { code in
                        HStack {
                            Text(CountryStore.shared.flag(code))
                            NavigationLink(CountryStore.shared.name(code)) { CountryDetailView(code: code) }
                        }
                    }
                    ForEach(detectedPlaces) { p in
                        HStack {
                            Text(CountryStore.shared.flag(p.countryCode))
                            Text(p.name)
                            Spacer()
                            if let existing = stops.first(where: { $0.name.lowercased() == p.name.lowercased() }) {
                                Button("Link") { video.stop = existing; video.isSorted = true }
                                    .buttonStyle(.bordered).controlSize(.small)
                                    .disabled(video.stop?.id == existing.id)
                            } else if trip != nil {
                                Button("Add to route") { addPlace = ResolvedPlace(p) }
                                    .buttonStyle(.borderedProminent).controlSize(.small)
                            }
                        }
                    }
                    if let days = video.durationDays {
                        Label("Suggested length: \(days) days", systemImage: "calendar")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            if !video.packingSuggestions.isEmpty {
                Section {
                    ForEach(video.packingSuggestions, id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button { addPacking([item]) } label: { Image(systemName: "plus.circle.fill") }
                                .buttonStyle(.borderless)
                        }
                    }
                    Button("Add all to packing list") { addPacking(video.packingSuggestions) }
                } header: {
                    Text("Packing items spotted")
                }
            }

            if !video.priceNotes.isEmpty {
                Section("Prices mentioned") {
                    Text(video.priceNotes.joined(separator: " · ")).font(.subheadline)
                }
            }

            Section {
                if video.caption.isEmpty {
                    Text("No caption yet.").foregroundStyle(.secondary)
                } else {
                    Text(video.caption).font(.callout).textSelection(.enabled)
                }
                Button(video.caption.isEmpty ? "Add caption" : "Edit caption") {
                    draftCaption = video.caption
                    editingCaption = true
                }
            } header: {
                Text("Caption")
            }

            Section("My notes") {
                TextField("Why you saved it, what to book…", text: $video.notes, axis: .vertical)
                    .lineLimit(3...10)
            }

            Section {
                Button("Delete", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(video.source)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $addPlace) { p in
            if let trip {
                AddStopConfirmView(trip: trip, place: p) { stop in
                    video.stop = stop
                    video.isSorted = true
                }
            }
        }
        .sheet(isPresented: $editingCaption) {
            NavigationStack {
                Form {
                    TextField("Caption", text: $draftCaption, axis: .vertical).lineLimit(5...20)
                }
                .navigationTitle("Caption")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingCaption = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save & sort") {
                            video.caption = draftCaption
                            if video.fetchState == .failed || video.fetchState == .pending { video.fetchState = .manual }
                            VideoImporter.apply(caption: draftCaption, to: video, trip: trip)
                            try? context.save()
                            editingCaption = false
                        }
                    }
                }
            }
        }
        .confirmationDialog("Delete this video?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                context.delete(video)
                try? context.save()
                dismiss()
            }
        }
    }

    private var detectedPlaces: [KnownPlace] {
        video.placeNames.compactMap { name in CountryStore.shared.places.first { $0.name == name } }
    }

    @MainActor
    private func refetch() async {
        working = true
        video.fetchState = .pending
        await VideoImporter.process(video, trip: trip, context: context)
        working = false
        // It was a duplicate of a video already saved and has been merged into it.
        if video.isDeleted || video.modelContext == nil { dismiss() }
    }

    private func addPacking(_ names: [String]) {
        let list: PackingList
        if let first = packingLists.first {
            list = first
        } else {
            list = PackingList(name: "Main backpack")
            context.insert(list)
        }
        for n in names {
            let item = PackingItem(name: n, category: "From TikTok")
            item.needToBuy = true
            item.link = video.urlString
            item.list = list
            context.insert(item)
        }
        try? context.save()
        app.flash("Added \(names.count) to \(list.name)")
    }

    private func addAsItem(kind: PlaceKind, to stop: Stop) {
        let item = PlaceItem(kind: kind, name: video.displayTitle, url: video.urlString,
                             currency: CountryStore.shared.country(stop.countryCode)?.mainCurrency ?? "GBP",
                             notes: video.notes)
        item.stop = stop
        context.insert(item)
        try? context.save()
        app.flash("Saved to \(stop.name) → \(kind.section.title)")
    }
}

/// Wraps children onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += s.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
