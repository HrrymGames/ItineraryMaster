import SwiftUI
import SwiftData
import ItineraryCore

/// Type folders (Route, Budget, Tour ideas…) and country folders as cards.
struct FolderGrid: View {
    let videos: [SavedVideo]
    let countries: [String]
    let counts: [String: Int]
    let trip: Trip
    var onCountry: (String) -> Void

    private var columns: [GridItem] { [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)] }

    var body: some View {
        Section("Folders") {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(VideoFolder.allCases) { f in
                    let n = videos.filter { $0.folder == f }.count
                    NavigationLink {
                        FolderVideosView(folder: f, trip: trip)
                    } label: {
                        FolderCard(title: f.label, symbol: f.symbol, count: n, color: Theme.color(for: f))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        if !countries.isEmpty {
            Section("Countries") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(countries.enumerated()), id: \.element) { i, code in
                        Button { onCountry(code) } label: {
                            FolderCard(title: CountryStore.shared.name(code), emoji: CountryStore.shared.flag(code),
                                       count: counts[code] ?? 0, color: Theme.countryPalette[i % Theme.countryPalette.count])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct FolderCard: View {
    let title: String
    var symbol: String?
    var emoji: String?
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let emoji {
                    Text(emoji).font(.title2)
                } else if let symbol {
                    Image(systemName: symbol).font(.title3).foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(color, in: RoundedRectangle(cornerRadius: 9))
                }
                Spacer()
                Text("\(count)").font(.title3.bold()).foregroundStyle(count > 0 ? color : .secondary)
            }
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Every video in one type folder, filterable by country.
struct FolderVideosView: View {
    let folder: VideoFolder
    let trip: Trip
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedVideo.savedAt, order: .reverse) private var videos: [SavedVideo]
    @State private var country: String?

    private var inFolder: [SavedVideo] { videos.filter { $0.folder == folder } }

    var body: some View {
        let all = inFolder
        let countries = Array(Set(all.flatMap(\.countryCodes))).sorted { CountryStore.shared.name($0) < CountryStore.shared.name($1) }
        let shown = country.map { c in all.filter { $0.countryCodes.contains(c) || $0.stop?.countryCode == c } } ?? all
        List {
            if !countries.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { country = nil } label: { ChipView(title: "All \(all.count)", selected: country == nil) }
                            ForEach(countries, id: \.self) { c in
                                Button { country = country == c ? nil : c } label: {
                                    ChipView(title: "\(CountryStore.shared.flag(c)) \(CountryStore.shared.name(c))", color: .blue, selected: country == c)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section {
                if shown.isEmpty {
                    Text("Nothing here yet. Open a saved video and choose \"\(folder.label)\" as its folder, or pick it when you share from TikTok.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(shown) { v in
                    NavigationLink { VideoDetailView(video: v, trip: trip) } label: { VideoRow(video: v) }
                        .contextMenu {
                            Section("Move to folder") {
                                ForEach(VideoFolder.allCases) { f in
                                    Button { v.folder = f; try? context.save() } label: { Label(f.label, systemImage: f.symbol) }
                                }
                            }
                        }
                }
            }
        }
        .navigationTitle(folder.label)
    }
}
