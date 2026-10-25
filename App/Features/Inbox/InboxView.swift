import SwiftUI
import SwiftData
import ItineraryCore

struct InboxView: View {
    let trip: Trip
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedVideo.savedAt, order: .reverse) private var videos: [SavedVideo]

    @State private var category: VideoCategory?
    @State private var countryCode: String?
    @State private var onlyUnsorted = false
    @State private var onlyFavourites = false
    @State private var search = ""
    @State private var showAddLink = false
    @State private var showHelp = false
    @State private var mode: SavedMode = .map
    @State private var openCountry: String?

    enum SavedMode: String, CaseIterable, Identifiable {
        case map, folders, all
        var id: String { rawValue }
        var label: String { self == .map ? "Map" : (self == .folders ? "Folders" : "All") }
    }

    /// Countries with saved videos or route stops, for the map and folders.
    private var mapCountries: [String] {
        var seen = Set<String>()
        let fromVideos = videos.flatMap { $0.countryCodes + [$0.stop?.countryCode].compactMap { $0 } }
        return (trip.countryCodesInRoute + fromVideos).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private var countryCounts: [String: Int] {
        var out: [String: Int] = [:]
        for v in videos {
            var codes = Set(v.countryCodes)
            if let c = v.stop?.countryCode, !c.isEmpty { codes.insert(c) }
            for c in codes { out[c, default: 0] += 1 }
        }
        return out
    }

    private var filtered: [SavedVideo] {
        let q = search.lowercased()
        return videos.filter { v in
            if let category, !v.categories.contains(category) { return false }
            if let countryCode, !v.countryCodes.contains(countryCode), v.stop?.countryCode != countryCode { return false }
            if onlyUnsorted && v.isSorted { return false }
            if onlyFavourites && !v.isFavourite { return false }
            if q.isEmpty { return true }
            if v.caption.lowercased().contains(q) || v.author.lowercased().contains(q) || v.notes.lowercased().contains(q) { return true }
            if v.placeNames.contains(where: { $0.lowercased().contains(q) }) { return true }
            return v.stop?.name.lowercased().contains(q) ?? false
        }
    }

    private var allCountries: [String] {
        var seen = Set<String>()
        return videos.flatMap(\.countryCodes).filter { seen.insert($0).inserted }
            .sorted { CountryStore.shared.name($0) < CountryStore.shared.name($1) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        PasteButton(payloadType: String.self) { strings in
                            Task { @MainActor in
                                var added = 0
                                for s in strings {
                                    if let v = VideoImporter.add(urlString: s, context: context) {
                                        added += 1
                                        await VideoImporter.process(v, trip: trip, context: context)
                                    }
                                }
                                app.flash(added > 0 ? "Saved!" : "No link found on the clipboard")
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        Button { showAddLink = true } label: { Label("Add link", systemImage: "link.badge.plus") }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        Spacer()
                        Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                            .buttonStyle(.borderless)
                    }
                    Picker("View", selection: $mode) {
                        ForEach(SavedMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if mode == .all { filterBar }
                }
                .listRowSeparator(.hidden)

                if mode == .map {
                    Section {
                        CountryOutlineMap(codes: mapCountries, counts: countryCounts) { openCountry = $0 }
                            .frame(height: 340)
                            .listRowInsets(EdgeInsets())
                    } footer: {
                        Text("Tap a country to see its videos, rules, money and stops. Pinch to zoom.")
                    }
                    countryFolderList
                } else if mode == .folders {
                    FolderGrid(videos: videos, countries: mapCountries, counts: countryCounts, trip: trip) { openCountry = $0 }
                } else if videos.isEmpty {
                    Section {
                        SaveHowToView()
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search
                } else {
                    Section {
                        ForEach(filtered) { v in
                            NavigationLink { VideoDetailView(video: v, trip: trip) } label: { VideoRow(video: v) }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { context.delete(v); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                                    Button { v.isSorted.toggle() } label: {
                                        Label(v.isSorted ? "Unsort" : "Sorted", systemImage: "checkmark.circle")
                                    }.tint(.green)
                                }
                                .swipeActions(edge: .leading) {
                                    Button { v.isFavourite.toggle() } label: { Label("Favourite", systemImage: "heart.fill") }.tint(.pink)
                                }
                        }
                    } header: {
                        Text("\(filtered.count) saved")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $search, prompt: "Search captions, places, notes")
            .onChange(of: search) { _, q in if !q.isEmpty { mode = .all } }
            .navigationDestination(item: $openCountry) { code in
                CountryDetailView(code: code, initialTab: .videos)
            }
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            for v in videos where !v.caption.isEmpty { VideoImporter.apply(caption: v.caption, to: v, trip: trip) }
                            try? context.save()
                            app.flash("Re-sorted \(videos.count) videos")
                        } label: { Label("Re-sort everything", systemImage: "wand.and.stars") }
                        Button {
                            Task { await VideoImporter.retryPending(trip: trip, context: context, includeAllFailures: true) }
                        } label: { Label("Retry failed downloads", systemImage: "arrow.clockwise") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .refreshable {
                _ = await VideoImporter.drainShareQueue(trip: trip, context: context)
                await VideoImporter.retryPending(trip: trip, context: context)
            }
            .sheet(isPresented: $showAddLink) { AddLinkView(trip: trip) }
            .sheet(isPresented: $showHelp) {
                NavigationStack {
                    ScrollView { SaveHowToView().padding() }
                        .navigationTitle("Saving videos")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHelp = false } } }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private var countryFolderList: some View {
        if !mapCountries.isEmpty {
            Section("Country folders") {
                ForEach(mapCountries, id: \.self) { code in
                    Button { openCountry = code } label: {
                        HStack {
                            Text(CountryStore.shared.flag(code)).font(.title3)
                            Text(CountryStore.shared.name(code)).foregroundStyle(.primary)
                            Spacer()
                            Text("\(countryCounts[code] ?? 0) videos").font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { category = nil; onlyUnsorted = false; onlyFavourites = false; countryCode = nil } label: {
                    ChipView(title: "All \(videos.count)", selected: category == nil && !onlyUnsorted && !onlyFavourites && countryCode == nil)
                }
                let unsorted = videos.filter { !$0.isSorted }.count
                Button { onlyUnsorted.toggle() } label: {
                    ChipView(title: "To sort \(unsorted)", symbol: "tray.full", color: .orange, selected: onlyUnsorted)
                }
                Button { onlyFavourites.toggle() } label: {
                    ChipView(title: "Favourites", symbol: "heart.fill", color: .pink, selected: onlyFavourites)
                }
                if !allCountries.isEmpty {
                    Menu {
                        Button("Any country") { countryCode = nil }
                        ForEach(allCountries, id: \.self) { c in
                            Button("\(CountryStore.shared.flag(c)) \(CountryStore.shared.name(c))") { countryCode = c }
                        }
                    } label: {
                        ChipView(title: countryCode.map { "\(CountryStore.shared.flag($0)) \(CountryStore.shared.name($0))" } ?? "Country",
                                 symbol: "globe", color: .blue, selected: countryCode != nil)
                    }
                }
                ForEach(VideoCategory.allCases) { c in
                    let n = videos.filter { $0.categories.contains(c) }.count
                    if n > 0 {
                        Button { category = (category == c ? nil : c) } label: {
                            ChipView(title: "\(c.label) \(n)", symbol: c.symbol, color: Theme.color(for: c), selected: category == c)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
        }
    }
}

struct VideoRow: View {
    let video: SavedVideo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ThumbnailView(data: video.thumbnail, cornerRadius: 8)
                .frame(width: 64, height: 86)
                .overlay(alignment: .topTrailing) {
                    if video.isFavourite {
                        Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink).padding(4)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(video.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(2)
                HStack(spacing: 4) {
                    if !video.author.isEmpty { Text("@\(video.author)") }
                    Text("· \(video.source)")
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 4) {
                    ForEach(video.categories.prefix(2), id: \.self) { c in
                        ChipView(title: c.label, symbol: c.symbol, color: Theme.color(for: c))
                    }
                    Text(video.countryCodes.prefix(4).map { CountryStore.shared.flag($0) }.joined())
                }
                .scaleEffect(0.9, anchor: .leading)
                HStack(spacing: 4) {
                    switch video.fetchState {
                    case .pending:
                        ProgressView().controlSize(.mini)
                        Text("Getting details…")
                    case .failed:
                        Image(systemName: video.fetchErrorIsTemporary ? "wifi.exclamationmark" : "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(video.fetchError ?? "Couldn't get details - tap to retry")
                            .lineLimit(2)
                    default:
                        if let stop = video.stop {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.accent)
                            Text(stop.name)
                        } else if !video.isSorted {
                            Image(systemName: "tray.full").foregroundStyle(.orange)
                            Text("To sort")
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Sorted")
                        }
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SaveHowToView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Save TikToks here", systemImage: "play.square.stack.fill").font(.title3.bold())
            step(1, "In TikTok, tap **Share** on a video.")
            step(2, "Tap **More** (or scroll the app row) and choose **Save to Itinerary**. The first time, tap *Edit* and add it to your favourites so it's always there.")
            step(3, "Or tap **Copy link** in TikTok, come back here and tap **Paste**.")
            step(4, "The app reads the caption on your phone and sorts it: itinerary, packing, activities, hostels, work & volunteering, budget… and spots the places mentioned.")
            Text("Works with TikTok and YouTube links. Instagram and other links are saved too - you can add your own notes and tags.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(Theme.accent, in: Circle())
            Text(text).font(.subheadline)
        }
    }
}

struct AddLinkView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @State private var link = ""
    @State private var caption = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("https://www.tiktok.com/…", text: $link, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    TextField("Optional: paste the caption or type what it's about", text: $caption, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    Text("Caption / description")
                } footer: {
                    Text("If you're offline, the caption helps the app sort the video straight away.")
                }
            }
            .navigationTitle("Add a link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let v = VideoImporter.add(urlString: link, context: context) else {
                            app.flash("That doesn't look like a link")
                            return
                        }
                        if !caption.isEmpty {
                            v.caption = caption
                            VideoImporter.apply(caption: caption, to: v, trip: trip)
                        }
                        dismiss()
                        Task { await VideoImporter.process(v, trip: trip, context: context) }
                    }
                    .bold()
                    .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
