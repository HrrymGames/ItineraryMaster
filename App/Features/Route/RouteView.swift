import SwiftUI
import SwiftData
import ItineraryCore

struct RouteView: View {
    @Bindable var trip: Trip
    @EnvironmentObject private var app: AppState
    @Environment(\.modelContext) private var context

    @State private var showAdd = false
    @State private var insertAfter: Stop?
    @State private var showReplan = false
    @State private var editMode: EditMode = .inactive
    @State private var stopToDelete: Stop?

    var body: some View {
        NavigationStack {
            let schedule = trip.schedule()
            let stops = trip.orderedStops
            List {
                Section {
                    RouteSummaryHeader(trip: trip, onReplan: { showReplan = true })
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Section {
                    if stops.isEmpty {
                        ContentUnavailableView {
                            Label("No stops yet", systemImage: "map")
                        } description: {
                            Text("Add the places you want to go. You can reorder them any time.")
                        } actions: {
                            Button("Add first stop") { showAdd = true }.buttonStyle(.borderedProminent)
                        }
                    }
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        NavigationLink {
                            StopDetailView(stop: stop)
                        } label: {
                            StopRow(stop: stop, index: index, dates: schedule[stop.id],
                                    previous: index > 0 ? trip.previousActiveStop(before: stop) : nil)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { stopToDelete = stop } label: { Label("Delete", systemImage: "trash") }
                            if stop.status == .skipped {
                                Button { stop.status = .planned } label: { Label("Restore", systemImage: "arrow.uturn.backward") }.tint(.blue)
                            } else {
                                Button { stop.status = .skipped } label: { Label("Skip", systemImage: "forward.fill") }.tint(.gray)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { trip.setCurrent(stop, arrived: Date(), leaving: Calendar.current.date(byAdding: .day, value: max(1, stop.nights), to: Date()) ?? Date()) } label: {
                                Label("I'm here", systemImage: "location.fill")
                            }.tint(.orange)
                        }
                        .contextMenu {
                            Button { stop.nights += 1 } label: { Label("Add a night", systemImage: "plus") }
                            Button { stop.nights = max(0, stop.nights - 1) } label: { Label("Remove a night", systemImage: "minus") }
                            Button { insertAfter = stop; showAdd = true } label: { Label("Insert stop after", systemImage: "text.insert") }
                            Button { app.show(stop: stop) } label: { Label("Show on map", systemImage: "map") }
                            Divider()
                            Button { trip.setCurrent(stop, arrived: Date(), leaving: Calendar.current.date(byAdding: .day, value: max(1, stop.nights), to: Date()) ?? Date()) } label: {
                                Label("I'm here now", systemImage: "location.fill")
                            }
                            Button { stop.status = stop.status == .skipped ? .planned : .skipped } label: {
                                Label(stop.status == .skipped ? "Restore stop" : "Skip stop", systemImage: "forward.fill")
                            }
                            Button(role: .destructive) { stopToDelete = stop } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .onMove { from, to in
                        trip.moveStops(from: from, to: to)
                        try? context.save()
                    }
                } header: {
                    if !stops.isEmpty {
                        HStack {
                            Text("\(stops.count) stops")
                            Spacer()
                            Text("Hold & drag to reorder").textCase(nil)
                        }
                    }
                }

                if !stops.isEmpty {
                    Section {
                        Button { insertAfter = nil; showAdd = true } label: {
                            Label("Add a stop", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Route")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { app.showMore = true } label: { Image(systemName: "line.3.horizontal.circle") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    Button { insertAfter = nil; showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddStopSearchView(trip: trip, insertAfter: insertAfter)
            }
            .sheet(isPresented: $showReplan) {
                ReplanView(trip: trip)
            }
            .confirmationDialog("Delete \(stopToDelete?.name ?? "stop")?", isPresented: Binding(get: { stopToDelete != nil }, set: { if !$0 { stopToDelete = nil } }), titleVisibility: .visible) {
                Button("Delete stop and its saved places", role: .destructive) {
                    if let s = stopToDelete { trip.removeStop(s, context: context) }
                    stopToDelete = nil
                }
                if let s = stopToDelete, s.status != .skipped {
                    Button("Skip it instead (keeps everything)") { s.status = .skipped; stopToDelete = nil }
                }
            }
        }
    }
}

struct RouteSummaryHeader: View {
    let trip: Trip
    var onReplan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name).font(.title2.bold())
                    Text("\(Fmt.dayYear.string(from: trip.startDate)) → \(Fmt.dayYear.string(from: trip.endDate))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                StatTile(title: "Nights", value: "\(trip.totalNights)", caption: weeksText)
                StatTile(title: "Countries", value: "\(trip.countryCodesInRoute.count)",
                         caption: trip.countryCodesInRoute.prefix(6).map { CountryStore.shared.flag($0) }.joined())
                StatTile(title: "Distance", value: Fmt.km(totalKm))
            }
            if let cur = trip.currentStop {
                let off = trip.daysOffPlan() ?? 0
                HStack(spacing: 10) {
                    Image(systemName: "location.fill").foregroundStyle(Theme.current)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're in \(cur.name)").font(.subheadline.bold())
                        Text(scheduleText(off))
                            .font(.caption).foregroundStyle(off < 0 ? Color.red : Color.secondary)
                    }
                    Spacer()
                    Button("Update", action: onReplan).buttonStyle(.bordered).controlSize(.small)
                }
                .card(padding: 12)
            } else if !trip.orderedStops.isEmpty {
                Button(action: onReplan) {
                    Label("Get back on route / I'm travelling now", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func scheduleText(_ off: Int) -> String {
        if off == 0 { return "Right on schedule" }
        let n = abs(off)
        let days = n == 1 ? "1 day" : "\(n) days"
        return off > 0 ? "\(days) ahead of plan" : "\(days) behind plan"
    }

    private var weeksText: String {
        trip.totalNights >= 7 ? Fmt.nights(trip.totalNights) : ""
    }

    private var totalKm: Double {
        let a = trip.activeStops
        guard a.count > 1 else { return 0 }
        return (1..<a.count).reduce(0) { $0 + Geo.distanceKm(a[$1 - 1].geoPoint, a[$1].geoPoint) }
    }
}

struct StopRow: View {
    @EnvironmentObject private var rates: CurrencyService
    let stop: Stop
    let index: Int
    let dates: ScheduledDates?
    let previous: Stop?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let previous, stop.status != .skipped {
                let leg = stop.legSummary(from: previous)
                let home = stop.trip?.homeCurrency ?? "GBP"
                HStack(spacing: 6) {
                    Image(systemName: leg.mode.symbol)
                    Text("\(leg.mode.label) · \(Fmt.km(leg.km)) · ~\(Fmt.hours(leg.hours))")
                    Text("· \(Fmt.money(leg.override ?? rates.convert(leg.typicalGBP, from: "GBP", to: home), home))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 40)
            }
            HStack(spacing: 12) {
                StopNumberBadge(number: index + 1, status: stop.status)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(stop.name).font(.headline).strikethrough(stop.status == .skipped)
                        Text(CountryStore.shared.flag(stop.countryCode))
                        if stop.pinnedArrival != nil { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange) }
                    }
                    HStack(spacing: 6) {
                        if stop.status == .skipped {
                            Text("Skipped").foregroundStyle(.secondary)
                        } else {
                            Text(Fmt.range(dates))
                            Text("·")
                            Text(Fmt.nights(stop.nights))
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    if !stop.items.isEmpty || !stop.videos.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(PlaceSection.allCases) { section in
                                let n = stop.items(of: section).count
                                if n > 0 {
                                    Label("\(n)", systemImage: section.symbol).foregroundStyle(Theme.color(for: section))
                                }
                            }
                            if !stop.videos.isEmpty {
                                Label("\(stop.videos.count)", systemImage: "play.square.fill").foregroundStyle(.pink)
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                    }
                }
                Spacer()
                if stop.status == .current {
                    Text("NOW").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.current, in: Capsule()).foregroundStyle(.white)
                }
            }
        }
        .opacity(stop.status == .skipped ? 0.55 : 1)
    }
}

/// "Get back on route": tell the app where you actually are and when you'll leave.
struct ReplanView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var stopID: UUID?
    @State private var arrived = Date()
    @State private var leaving = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("I'm in", selection: $stopID) {
                        Text("Choose a stop").tag(UUID?.none)
                        ForEach(trip.orderedStops) { s in
                            Text("\(CountryStore.shared.flag(s.countryCode)) \(s.name)").tag(UUID?.some(s.id))
                        }
                    }
                    DatePicker("Arrived", selection: $arrived, displayedComponents: .date)
                    DatePicker("Leaving", selection: $leaving, in: arrived..., displayedComponents: .date)
                } footer: {
                    Text("Earlier stops are marked visited and everything after this stop moves to fit. Stops with a pinned date (like a booked flight) stay put.")
                }
                if let id = stopID, let stop = trip.orderedStops.first(where: { $0.id == id }) {
                    let r = RouteScheduler.replan(arrivedOn: arrived, leavingOn: leaving)
                    Section("Preview") {
                        LabeledContent("Nights in \(stop.name)", value: "\(r.nights)")
                        if let next = trip.nextActiveStop(after: stop) {
                            LabeledContent("Then", value: "\(next.name) on \(Fmt.day.string(from: leaving))")
                        }
                    }
                }
                Section {
                    Button {
                        trip.advance()
                        try? context.save()
                        dismiss()
                    } label: {
                        Label("I'm leaving today → move to next stop", systemImage: "arrow.right.circle.fill")
                    }
                }
            }
            .navigationTitle("Get back on route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        if let id = stopID, let stop = trip.orderedStops.first(where: { $0.id == id }) {
                            trip.setCurrent(stop, arrived: arrived, leaving: leaving)
                            try? context.save()
                        }
                        dismiss()
                    }
                    .disabled(stopID == nil)
                }
            }
            .onAppear {
                let schedule = trip.schedule()
                if let cur = trip.currentStop {
                    stopID = cur.id
                    if let d = schedule[cur.id] { arrived = d.arrival; leaving = d.departure }
                } else if let idx = RouteScheduler.indexOfStop(on: Date(), in: trip.orderedStops.compactMap { schedule[$0.id] }) {
                    let s = trip.orderedStops[idx]
                    stopID = s.id
                    if let d = schedule[s.id] { arrived = d.arrival; leaving = d.departure }
                }
            }
        }
    }
}
