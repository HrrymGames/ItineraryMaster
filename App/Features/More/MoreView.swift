import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ItineraryCore

struct MoreView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var rates: CurrencyService

    @State private var exportDoc: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingRestore: BackupFile?
    @State private var confirmDemo = false
    @State private var confirmReset = false
    @State private var message: String?

    private static let currencies = ["GBP", "EUR", "USD", "AUD", "NZD", "CAD"]

    var body: some View {
        NavigationStack {
            List {
                Section("Trip") {
                    TextField("Trip name", text: $trip.name)
                    DatePicker("Start date", selection: $trip.startDate, displayedComponents: .date)
                    Picker("Home currency", selection: $trip.homeCurrency) {
                        ForEach(Self.currencies, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Text("Total budget")
                        Spacer()
                        TextField("0", value: $trip.totalBudget, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                }

                Section {
                    NavigationLink { CountryListView() } label: { Label("Country guides", systemImage: "globe.europe.africa.fill") }
                    NavigationLink {
                        ScrollView { SaveHowToView().padding() }.navigationTitle("Saving TikToks")
                    } label: { Label("How to save TikToks", systemImage: "play.square.stack") }
                }

                Section {
                    Button {
                        do {
                            let data = try BackupService.makeBackup(context: context).encoded()
                            exportDoc = BackupDocument(data: data)
                            showExporter = true
                        } catch {
                            message = "Couldn't create backup: \(error.localizedDescription)"
                        }
                    } label: { Label("Export backup", systemImage: "square.and.arrow.up") }
                    Button { showImporter = true } label: { Label("Restore from backup", systemImage: "square.and.arrow.down") }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Sideloaded apps keep their data when SideStore refreshes them, but deleting the app deletes everything. Export a backup to Files or iCloud Drive now and then.")
                }

                Section {
                    Button { confirmDemo = true } label: { Label("Load demo trip (South-East Asia)", systemImage: "wand.and.stars") }
                    Button(role: .destructive) { confirmReset = true } label: { Label("Erase everything", systemImage: "trash") }
                }

                Section("Installing & updating") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Free Apple ID apps need refreshing every 7 days. Open SideStore (or iLoader) and tap Refresh before the timer runs out - your data stays.")
                        Text("New versions: download the latest ItineraryMaster.ipa from the GitHub Releases page and install it over the top in SideStore.")
                    }
                    .font(.footnote)
                    Link(destination: URL(string: "https://github.com/HrrymGames/ItineraryMaster/releases/latest")!) {
                        Label("Latest release", systemImage: "arrow.down.app")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    LabeledContent("Exchange rates", value: rates.isLive ? Fmt.dayYear.string(from: rates.rates.fetchedAt) : "Built-in")
                    Text("Country data: mledoze/countries (ODbL) + hand-curated travel tips. Place info from Wikipedia. Rates from open.er-api.com / Frankfurter. Always double-check visa and safety info on GOV.UK.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .json, defaultFilename: backupName) { result in
                if case .failure(let e) = result { message = e.localizedDescription } else { message = "Backup saved ✓" }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        pendingRestore = try BackupFile.decode(Data(contentsOf: url))
                    } catch {
                        message = "That file isn't a valid backup."
                    }
                case .failure(let e):
                    message = e.localizedDescription
                }
            }
            .confirmationDialog("Replace everything with this backup?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }), titleVisibility: .visible) {
                Button("Restore", role: .destructive) {
                    if let file = pendingRestore {
                        // Close this screen first: it shows the trip that's about to be replaced.
                        let ctx = context
                        let state = app
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            do {
                                try BackupService.restore(file, context: ctx)
                                state.flash("Backup restored")
                            } catch {
                                state.flash("Restore failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    pendingRestore = nil
                }
            } message: {
                if let f = pendingRestore {
                    Text("Backup from \(Fmt.dayYear.string(from: f.exportedAt)) with \(f.trips.first?.stops.count ?? 0) stops and \(f.videos.count) videos.")
                }
            }
            .confirmationDialog("Replace your route with the demo trip?", isPresented: $confirmDemo, titleVisibility: .visible) {
                Button("Load demo", role: .destructive) {
                    Seeder.loadDemo(into: trip, context: context)
                    dismiss()
                }
            } message: {
                Text("Your current stops and budget lines will be replaced. Export a backup first if you want to keep them.")
            }
            .confirmationDialog("Erase all trips, videos and lists?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) {
                    let ctx = context
                    dismiss()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        try? BackupService.wipe(context: ctx)
                        UserDefaults.standard.removeObject(forKey: "seededStarterLists.v1")
                        Seeder.ensureTrip(context: ctx)
                    }
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var backupName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "Itinerary-backup-\(f.string(from: Date())).json"
    }
}
