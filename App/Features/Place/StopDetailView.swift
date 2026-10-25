import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import ItineraryCore

struct StopDetailView: View {
    @Bindable var stop: Stop
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var editingItem: PlaceItem?
    @State private var newItemSection: PlaceSection?
    @State private var viewingPhoto: StopPhoto?
    @State private var loadingWiki = false
    @State private var triedWiki = false
    @State private var showAllWiki = false
    @State private var confirmDelete = false
    @State private var openVideo: SavedVideo?
    @State private var showAddAfter = false

    private var trip: Trip? { stop.trip }
    private var dates: ScheduledDates? { trip?.schedule()[stop.id] }
    private var country: CountryInfo? { CountryStore.shared.country(stop.countryCode) }
    private var homeCurrency: String { trip?.homeCurrency ?? "GBP" }

    var body: some View {
        List {
            Section {
                PhotoHeader(stop: stop, onTap: { viewingPhoto = $0 })
                    .frame(height: 230)
                    .listRowInsets(EdgeInsets())
                HStack {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        Label("Add photos", systemImage: "photo.on.rectangle.angled")
                    }
                    Spacer()
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: { Label("Camera", systemImage: "camera.fill") }
                    }
                }
                .buttonStyle(.borderless)
            }

            Section {
                if let country {
                    NavigationLink {
                        CountryDetailView(code: country.code)
                    } label: {
                        Label { Text(country.name) } icon: { Text(country.flag) }
                    }
                }
                Picker("Status", selection: Binding(get: { stop.status }, set: { stop.status = $0 })) {
                    ForEach(StopStatus.allCases, id: \.self) { s in Text(s.label).tag(s) }
                }
                Stepper(value: $stop.nights, in: 0...365) {
                    HStack {
                        Text("Nights")
                        Spacer()
                        Text("\(stop.nights)").foregroundStyle(.secondary)
                    }
                }
                if let dates {
                    LabeledContent("Dates", value: Fmt.range(dates))
                }
                Toggle(isOn: Binding(get: { stop.pinnedArrival != nil }, set: { on in
                    stop.pinnedArrival = on ? (dates?.arrival ?? Date()) : nil
                })) {
                    VStack(alignment: .leading) {
                        Text("Fixed arrival date")
                        Text("e.g. a booked flight - later stops move around it").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let pinned = stop.pinnedArrival {
                    DatePicker("Arrive on", selection: Binding(get: { pinned }, set: { stop.pinnedArrival = $0 }), displayedComponents: .date)
                }
            }

            if let trip, let prev = trip.previousActiveStop(before: stop) {
                Section("Getting here from \(prev.name)") {
                    let km = Geo.distanceKm(prev.geoPoint, stop.geoPoint)
                    Picker("Transport", selection: Binding(get: { stop.transportMode }, set: { stop.transportMode = $0 })) {
                        ForEach(TransportMode.allCases) { m in Label(m.label, systemImage: m.symbol).tag(m) }
                    }
                    LabeledContent("Distance", value: "\(Fmt.km(km)) · ~\(Fmt.hours(Geo.estimatedHours(km: km, mode: stop.transportMode)))")
                    HStack {
                        Text("Cost (\(homeCurrency))")
                        Spacer()
                        TextField("0", value: $stop.transportCost, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    TextField("Notes (e.g. 12Go sleeper bus, 8pm)", text: $stop.transportNotes, axis: .vertical)
                    Link(destination: rome2rioURL(from: prev)) {
                        Label("Compare routes on Rome2Rio", systemImage: "arrow.triangle.swap")
                    }
                }
            }

            Section("About \(stop.name)") {
                if let summary = stop.wikiSummary {
                    Text(summary)
                        .font(.callout)
                        .lineLimit(showAllWiki ? nil : 5)
                        .onTapGesture { withAnimation { showAllWiki.toggle() } }
                } else if loadingWiki {
                    HStack { ProgressView(); Text("Loading info…").foregroundStyle(.secondary) }
                } else {
                    Button { Task { await loadWiki() } } label: {
                        Label("Load info & picture (needs internet)", systemImage: "arrow.down.circle")
                    }
                }
                if let country {
                    HStack(spacing: 14) {
                        Label(country.mainCurrency, systemImage: "banknote")
                        if !country.plugs.isEmpty { Label("Plug \(country.plugs)", systemImage: "powerplug") }
                        if let usd = country.dailyCostUSD { Label("~$\(Int(usd))/day", systemImage: "chart.bar") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            ForEach(PlaceSection.allCases) { section in
                let items = stop.items(of: section)
                if !items.isEmpty || section != .other {
                    Section {
                        ForEach(items) { item in
                            Button { editingItem = item } label: { PlaceItemRow(item: item) }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) { context.delete(item); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                                    Button { item.isBooked.toggle() } label: { Label(item.isBooked ? "Unbook" : "Booked", systemImage: "checkmark.circle") }.tint(.green)
                                }
                        }
                        HStack {
                            Button { newItemSection = section } label: {
                                Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                            Spacer()
                            let links = section.searchLinks(for: "\(stop.name) \(country?.name ?? "")")
                            if !links.isEmpty {
                                Menu {
                                    ForEach(links, id: \.0) { link in
                                        Link(link.0, destination: link.1)
                                    }
                                } label: {
                                    Label("Find ideas", systemImage: "safari").font(.subheadline)
                                }
                            }
                        }
                    } header: {
                        Label(section.title, systemImage: section.symbol).foregroundStyle(Theme.color(for: section))
                    }
                }
            }

            Section("Saved videos") {
                if stop.videos.isEmpty {
                    Text("Videos you save that mention \(stop.name) appear here automatically, or link them from the Saved tab.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(stop.videos.sorted { $0.savedAt > $1.savedAt }) { v in
                                Button { openVideo = v } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ThumbnailView(data: v.thumbnail)
                                            .frame(width: 110, height: 150)
                                        Text(v.displayTitle).font(.caption2).lineLimit(2).frame(width: 110, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Link(destination: tiktokSearchURL) {
                    Label("Search TikTok for \(stop.name)", systemImage: "magnifyingglass")
                }
            }

            Section("My notes") {
                TextField("Anything to remember…", text: $stop.notes, axis: .vertical)
                    .lineLimit(3...12)
            }

            Section {
                Button { app.show(stop: stop); dismiss() } label: { Label("Show on map", systemImage: "map") }
                Button { showAddAfter = true } label: { Label("Insert a stop after this", systemImage: "text.insert") }
                Button { openInMaps() } label: { Label("Open in Apple Maps", systemImage: "arrow.up.right.square") }
                Link(destination: googleMapsURL) { Label("Open in Google Maps", systemImage: "globe") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete stop", systemImage: "trash") }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if stop.wikiSummary == nil && !triedWiki {
                triedWiki = true
                await loadWiki()
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task { await importPhotos(items) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { data in addPhoto(data) }.ignoresSafeArea()
        }
        .sheet(item: $editingItem) { item in
            PlaceItemEditor(stop: stop, item: item, section: item.kind.section)
        }
        .sheet(item: $newItemSection) { section in
            PlaceItemEditor(stop: stop, item: nil, section: section)
        }
        .sheet(item: $viewingPhoto) { photo in
            PhotoViewer(photo: photo)
        }
        .sheet(item: $openVideo) { v in
            NavigationStack { VideoDetailView(video: v, trip: trip) }
        }
        .sheet(isPresented: $showAddAfter) {
            if let trip { AddStopSearchView(trip: trip, insertAfter: stop) }
        }
        .confirmationDialog("Delete \(stop.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete stop", role: .destructive) {
                let t = trip
                dismiss()
                t?.removeStop(stop, context: context)
            }
        } message: {
            Text("Its photos and saved places will be deleted too. Tip: you can skip a stop instead.")
        }
    }

    private var tiktokSearchURL: URL {
        var c = URLComponents(string: "https://www.tiktok.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: "\(stop.name) travel")]
        return c.url!
    }

    private var googleMapsURL: URL {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(stop.latitude),\(stop.longitude)")!
    }

    private func rome2rioURL(from prev: Stop) -> URL {
        let a = prev.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? prev.name
        let b = stop.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? stop.name
        return URL(string: "https://www.rome2rio.com/map/\(a)/\(b)") ?? URL(string: "https://www.rome2rio.com")!
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: stop.coordinate))
        item.name = stop.name
        item.openInMaps()
    }

    @MainActor
    private func loadWiki() async {
        loadingWiki = true
        defer { loadingWiki = false }
        if let r = await WikiService.bestSummary(place: stop.name, countryName: country?.name) {
            stop.wikiSummary = r.text
            if let img = r.image { stop.wikiImage = img }
            try? context.save()
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                addPhoto(data)
            }
        }
        pickerItems = []
    }

    private func addPhoto(_ data: Data) {
        let jpeg = ImageTools.downscaled(data, maxDimension: 2000, quality: 0.8) ?? data
        let photo = StopPhoto(data: jpeg)
        photo.stop = stop
        context.insert(photo)
        try? context.save()
    }
}


struct PlaceItemRow: View {
    let item: PlaceItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbol)
                .frame(width: 30, height: 30)
                .background(Theme.color(for: item.kind.section).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Theme.color(for: item.kind.section))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(.subheadline.weight(.semibold))
                    if item.isBooked {
                        Text("BOOKED").font(.system(size: 9, weight: .heavy)).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.green.opacity(0.2), in: Capsule()).foregroundStyle(.green)
                    }
                }
                HStack(spacing: 6) {
                    Text(item.kind.label)
                    if item.price > 0 { Text("· \(Fmt.money(item.price, item.currency))") }
                    if item.rating > 0 { Text("· " + String(repeating: "★", count: item.rating)).foregroundStyle(.yellow) }
                    if item.coordinate != nil { Image(systemName: "mappin") }
                }
                .font(.caption).foregroundStyle(.secondary)
                if !item.notes.isEmpty {
                    Text(item.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if let url = item.url.asURL {
                Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                    .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
    }
}

struct PhotoHeader: View {
    let stop: Stop
    var onTap: (StopPhoto) -> Void

    var body: some View {
        let photos = stop.sortedPhotos
        ZStack(alignment: .bottomLeading) {
            if photos.isEmpty {
                if let data = stop.wikiImage, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Theme.accent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44)).foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                TabView {
                    ForEach(photos) { p in
                        if let ui = UIImage(data: p.data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .onTapGesture { onTap(p) }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(CountryStore.shared.flag(stop.countryCode)) \(stop.name)").font(.title.bold())
                Text(stop.status.label).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding()
            .allowsHitTesting(false)
        }
        .clipped()
    }
}

struct PhotoViewer: View {
    let photo: StopPhoto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let ui = UIImage(data: photo.data) {
                    Image(uiImage: ui).resizable().scaledToFit()
                        .scaleEffect(scale)
                        .gesture(MagnificationGesture().onChanged { scale = max(1, $0) }.onEnded { _ in withAnimation { scale = 1 } })
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let ui = UIImage(data: photo.data) {
                        ShareLink(item: Image(uiImage: ui), preview: SharePreview("Photo", image: Image(uiImage: ui)))
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        context.delete(photo)
                        try? context.save()
                        dismiss()
                    } label: { Image(systemName: "trash") }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
