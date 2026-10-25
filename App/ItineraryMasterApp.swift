import SwiftUI
import SwiftData
import ItineraryCore

enum AppTab: String, CaseIterable {
    case map, route, inbox, packing, budget
}

/// Navigation state shared across tabs.
final class AppState: ObservableObject {
    @Published var tab: AppTab = .map
    @Published var focusStopID: UUID?
    @Published var showMore = false
    @Published var toast: String?

    func show(stop: Stop) {
        focusStopID = stop.id
        tab = .map
    }

    func flash(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toast == message { self?.toast = nil }
        }
    }
}

@main
struct ItineraryMasterApp: App {
    let container: ModelContainer
    @StateObject private var appState = AppState()
    @StateObject private var currency = CurrencyService.shared

    init() {
        let schema = Schema(AppSchema.models)
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            // Last resort so the app still opens; data won't persist this session.
            print("SwiftData store failed: \(error)")
            container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(currency)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var currency: CurrencyService
    @Query(sort: \Trip.createdAt) private var trips: [Trip]
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if let trip = trips.first {
                TabView(selection: $app.tab) {
                    TripMapView(trip: trip)
                        .tabItem { Label("Map", systemImage: "map.fill") }
                        .tag(AppTab.map)
                    RouteView(trip: trip)
                        .tabItem { Label("Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill") }
                        .tag(AppTab.route)
                    InboxView(trip: trip)
                        .tabItem { Label("Saved", systemImage: "play.square.stack.fill") }
                        .tag(AppTab.inbox)
                    PackingView(trip: trip)
                        .tabItem { Label("Packing", systemImage: "backpack.fill") }
                        .tag(AppTab.packing)
                    BudgetView(trip: trip)
                        .tabItem { Label("Budget", systemImage: "sterlingsign.circle.fill") }
                        .tag(AppTab.budget)
                }
                .sheet(isPresented: $app.showMore) {
                    MoreView(trip: trip)
                }
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .top) {
            if let toast = app.toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring, value: app.toast)
        .task { await bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await onForeground() } }
        }
        .onOpenURL { url in handle(url) }
    }

    @MainActor
    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let trip = Seeder.ensureTrip(context: context)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoData") && trip.stops.isEmpty {
            Seeder.loadDemo(into: trip, context: context)
        }
        if let start = UserDefaults.standard.string(forKey: "startTab") {
            if start == "more" { app.showMore = true } else if let tab = AppTab(rawValue: start) { app.tab = tab }
        }
        await onForeground()
    }

    @MainActor
    private func onForeground() async {
        let trip = trips.first
        let n = await VideoImporter.drainShareQueue(trip: trip, context: context)
        if n > 0 { app.flash("Saved \(n) new video\(n == 1 ? "" : "s")") }
        await currency.refreshIfStale(base: trip?.homeCurrency ?? "GBP")
        await VideoImporter.retryPending(trip: trip, context: context)
    }

    /// itinerarymaster://save?url=<link>  (handy for iOS Shortcuts)
    private func handle(_ url: URL) {
        guard url.scheme == "itinerarymaster" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if url.host == "save", let link = items.first(where: { $0.name == "url" })?.value {
            if let video = VideoImporter.add(urlString: link, context: context) {
                app.tab = .inbox
                app.flash("Saved to your inbox")
                Task { await VideoImporter.process(video, trip: trips.first, context: context) }
            }
        } else if url.host == "inbox" {
            app.tab = .inbox
        }
    }
}
