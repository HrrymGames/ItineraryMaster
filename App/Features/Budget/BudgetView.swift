import SwiftUI
import SwiftData
import Charts
import ItineraryCore

struct BudgetView: View {
    @Bindable var trip: Trip
    @EnvironmentObject private var rates: CurrencyService
    @Environment(\.modelContext) private var context

    @State private var addingExpense = false
    @State private var editingExpense: Expense?
    @State private var addingLine = false
    @State private var editingLine: BudgetLine?
    @State private var editingBudget = false
    @State private var showConverter = false
    @State private var expanded: Set<String> = []

    private var home: String { trip.homeCurrency }

    var body: some View {
        NavigationStack {
            let plan = BudgetSync.plan(for: trip, rates: rates.rates)
            let s = summary(plan)
            List {
                Section {
                    Picker("Travel style", selection: Binding(get: { trip.travelStyle }, set: { trip.travelStyle = $0 })) {
                        ForEach(TravelStyle.allCases) { Text($0.shortLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(trip.travelStyle.blurb).font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    overview(s)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                planSection(plan, s)
                countriesSection(plan, s)
                accommodationSection(plan)
                legsSection(plan)
                toursSection(plan)
                fixedSection()
                spendingSection()

                Section {
                    Button { showConverter = true } label: { Label("Currency converter", systemImage: "arrow.left.arrow.right.circle") }
                    HStack {
                        Text(rates.isLive ? "Rates updated \(Fmt.dayYear.string(from: rates.rates.fetchedAt))" : "Using built-in approximate rates")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if rates.isRefreshing { ProgressView() } else {
                            Button("Refresh") { Task { await rates.refresh(base: home) } }.font(.caption)
                        }
                    }
                } footer: {
                    Text("Typical prices are researched backpacker figures (checked \(Costs.checked)). Tap anything to use your own numbers.")
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingExpense = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .task(id: BudgetSync.signature(trip)) {
                BudgetSync.syncAutoLines(trip, context: context)
                try? context.save()
            }
            .sheet(isPresented: $addingExpense) { ExpenseEditor(trip: trip, expense: nil) }
            .sheet(item: $editingExpense) { e in ExpenseEditor(trip: trip, expense: e) }
            .sheet(isPresented: $addingLine) { BudgetLineEditor(trip: trip, line: nil) }
            .sheet(item: $editingLine) { l in BudgetLineEditor(trip: trip, line: l) }
            .sheet(isPresented: $showConverter) { ConverterView(home: home).presentationDetents([.medium]) }
            .sheet(isPresented: $editingBudget) { TotalBudgetEditor(trip: trip).presentationDetents([.medium]) }
        }
    }

    private func summary(_ plan: BudgetPlan) -> BudgetSummary {
        let spent = trip.expenses.map { SpentItem(category: $0.category, cost: Money($0.amount, $0.currency), date: $0.date, countryCode: $0.countryCode) }
        return BudgetCalculator.summarize(currency: home, totalBudget: trip.totalBudget, stays: [], fixed: plan.asFixedCosts, spent: spent,
                                          rates: rates.rates, today: max(Date(), trip.startDate), tripEnd: trip.endDate)
    }

    // MARK: Sections

    @ViewBuilder
    private func planSection(_ plan: BudgetPlan, _ s: BudgetSummary) -> some View {
        Section {
            HStack(spacing: 10) {
                StatTile(title: "Whole trip", value: Fmt.money(plan.total, home),
                         caption: plan.nights > 0 ? "\(Fmt.money(plan.perDay, home))/day on the road" : nil)
                StatTile(title: s.planHeadroom >= 0 ? "Under budget by" : "Over budget by",
                         value: Fmt.money(abs(s.planHeadroom), home),
                         caption: trip.totalBudget > 0 ? nil : "Set your budget above",
                         tint: s.planHeadroom >= 0 ? .green : .red)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            if plan.total > 0 {
                let cats = BudgetCategory.allCases.filter { (plan.byCategory[$0] ?? 0) > 0 }
                Chart(cats) { c in
                    SectorMark(angle: .value("Amount", plan.byCategory[c] ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .foregroundStyle(Theme.color(for: c))
                        .cornerRadius(3)
                }
                .frame(height: 190)
                .chartBackground { _ in
                    VStack {
                        Text("Plan").font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.money(plan.total, home)).font(.headline)
                    }
                }
                ForEach(BudgetCategory.allCases.filter { (plan.byCategory[$0] ?? 0) > 0 || (s.spentByCategory[$0] ?? 0) > 0 }) { c in
                    CategoryLine(category: c, planned: plan.byCategory[c] ?? 0, spent: s.spentByCategory[c] ?? 0, currency: home)
                }
            }
        } header: {
            Text("The plan")
        } footer: {
            Text("Beds × nights, daily food/transport/necessities for each country, every tour you've added, travel between stops, and fixed costs like flights, insurance and visas.")
        }
    }

    @ViewBuilder
    private func countriesSection(_ plan: BudgetPlan, _ s: BudgetSummary) -> some View {
        let rows = BudgetSync.countryNights(trip)
        Section("By country") {
            if rows.isEmpty {
                Text("Add stops to your route to see costs per country.").foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.code) { row in
                NavigationLink { CountryDetailView(code: row.code, initialTab: .money) } label: {
                    HStack {
                        Text(CountryStore.shared.flag(row.code)).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CountryStore.shared.name(row.code))
                            Text("\(Fmt.nights(row.nights)) · typical \(Fmt.money(typicalDay(row.code), home))/day")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.money(plan.byCountry[row.code] ?? 0, home)).font(.subheadline.weight(.semibold))
                            if let spent = s.spentByCountry[row.code], spent > 0 {
                                Text("spent \(Fmt.money(spent, home))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func typicalDay(_ code: String) -> Double {
        let gbp = Costs.db.countries[code]?.typicalDay(trip.travelStyle)
            ?? (Costs.db.dailyCosts(country: code, style: trip.travelStyle).total + (trip.travelStyle == .budget ? 12 : 35))
        return rates.convert(gbp, from: "GBP", to: home)
    }

    @ViewBuilder
    private func accommodationSection(_ plan: BudgetPlan) -> some View {
        let total = plan.byCategory[.accommodation] ?? 0
        Section {
            DisclosureGroup(isExpanded: binding("acc")) {
                ForEach(plan.stops.filter { $0.nights > 0 }) { p in
                    stopLink(p.id) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                Text("\(Fmt.nights(p.nights)) × \(Fmt.money(p.accommodation.perNight, home)) · \(p.accommodation.source.label)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Fmt.money(p.accommodation.total, home)).foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                totalLabel("Accommodation", symbol: "bed.double.fill", amount: total)
            }
        } footer: {
            Text("Add hostels at a stop to use their price; booked ones count first.")
        }
    }

    @ViewBuilder
    private func legsSection(_ plan: BudgetPlan) -> some View {
        let legs = plan.stops.filter { $0.leg != nil }
        Section {
            DisclosureGroup(isExpanded: binding("legs")) {
                ForEach(Array(legs.enumerated()), id: \.element.id) { i, p in
                    if let leg = p.leg {
                        stopLink(p.id) {
                            HStack(spacing: 10) {
                                Image(systemName: leg.mode.symbol).frame(width: 24).foregroundStyle(.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("→ \(p.name)").lineLimit(1)
                                    Text("\(leg.mode.label) · ~\(Fmt.hours(leg.hours))\(p.legIsTypical ? (leg.fromTable ? " · typical" : " · estimate") : " · your price")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Fmt.money(p.legCost, home)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                totalLabel("Between stops", symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", amount: plan.byCategory[.travel] ?? 0)
            }
        } footer: {
            Text("Uses how backpackers usually travel each leg (sleeper trains, slow boats, buses, ferries, flights). Tap a leg to change it.")
        }
    }

    @ViewBuilder
    private func toursSection(_ plan: BudgetPlan) -> some View {
        let items = trip.orderedStops.filter { $0.status != .skipped }.flatMap { s in
            s.items.filter { $0.kind != .hostel && $0.price > 0 }.map { (stop: s, item: $0) }
        }
        let total = items.reduce(0.0) { $0 + rates.convert($1.item.price, from: $1.item.currency, to: home) }
        Section {
            DisclosureGroup(isExpanded: binding("tours")) {
                if items.isEmpty {
                    Text("Add tours and activities at each stop (e.g. Ha Giang Loop, Khao Sok) and they'll appear here.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(items, id: \.item.id) { pair in
                    stopLink(pair.stop.id.uuidString) {
                        HStack {
                            Image(systemName: pair.item.kind.symbol).frame(width: 24).foregroundStyle(Theme.color(for: pair.item.kind.section))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pair.item.name).lineLimit(1)
                                Text(pair.stop.name + (pair.item.isBooked ? " · booked" : "")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Fmt.money(pair.item.price, pair.item.currency)).foregroundStyle(.secondary)
                        }
                    }
                }
            } label: {
                totalLabel("Tours & activities", symbol: "figure.hiking", amount: total)
            }
        }
    }

    @ViewBuilder
    private func fixedSection() -> some View {
        let lines = trip.budgetLines
        let groups = orderedGroups(lines)
        ForEach(groups, id: \.self) { g in
            Section(g) {
                ForEach(lines.filter { groupName($0) == g }.sorted { $0.name < $1.name }) { line in
                    FixedLineRow(line: line, home: home) { editingLine = line }
                        .swipeActions {
                            if line.autoKey == nil {
                                Button(role: .destructive) { context.delete(line); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                }
            }
        }
        Section {
            Button { addingLine = true } label: { Label("Add your own fixed cost", systemImage: "plus") }
        } footer: {
            Text("Switch off anything you already have (e.g. a backpack) - it's taken out of the plan.")
        }
    }

    private func groupName(_ l: BudgetLine) -> String { l.group.isEmpty ? "Your fixed costs" : l.group }

    private func orderedGroups(_ lines: [BudgetLine]) -> [String] {
        let order = ["Flights", "Visas & entry", "Insurance", "Health", "Documents", "Phone & data", "Gear", "Money", "Before you go", "Your fixed costs"]
        let present = Set(lines.map(groupName))
        return order.filter(present.contains) + present.subtracting(order).sorted()
    }

    @ViewBuilder
    private func spendingSection() -> some View {
        Section {
            Button { addingExpense = true } label: {
                Label("Log spending", systemImage: "plus.circle.fill").font(.headline)
            }
            let recent = trip.expenses.sorted { $0.date > $1.date }
            ForEach(recent.prefix(30)) { e in
                Button { editingExpense = e } label: { ExpenseRow(expense: e, home: home) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { context.delete(e); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                    }
            }
            if recent.count > 30 {
                Text("+ \(recent.count - 30) older").font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Spending")
        }
    }

    // MARK: Helpers

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { expanded.contains(key) }, set: { if $0 { expanded.insert(key) } else { expanded.remove(key) } })
    }

    private func totalLabel(_ title: String, symbol: String, amount: Double) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text(Fmt.money(amount, home)).font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private func stopLink<Content: View>(_ id: String, @ViewBuilder _ content: () -> Content) -> some View {
        if let stop = trip.stops.first(where: { $0.id.uuidString == id }) {
            NavigationLink { StopDetailView(stop: stop) } label: { content() }
        } else {
            content()
        }
    }

    private func overview(_ s: BudgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Left to spend").font(.subheadline).foregroundStyle(.secondary)
                    Text(Fmt.money(s.remaining, home))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(s.remaining >= 0 ? Color.primary : Color.red)
                        .minimumScaleFactor(0.5)
                }
                Spacer()
                Button { editingBudget = true } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Budget").font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.money(s.totalBudget, home)).font(.headline)
                        Text("Edit").font(.caption2).foregroundStyle(Theme.accent)
                    }
                }
                .buttonStyle(.plain)
            }
            ProgressView(value: min(1, s.spentFraction))
                .tint(s.spentFraction > 1 ? .red : Theme.accent)
            HStack(spacing: 10) {
                StatTile(title: "Spent", value: Fmt.money(s.spentTotal, home))
                StatTile(title: "Per day left", value: Fmt.money(s.dailyAllowance, home),
                         caption: s.daysLeft > 0 ? "for \(Fmt.nights(s.daysLeft))" : nil,
                         tint: s.dailyAllowance >= s.plannedPerDay * 0.8 ? .green : .orange)
            }
        }
    }
}

/// A fixed cost with an include toggle (auto lines) and its amount.
struct FixedLineRow: View {
    @Bindable var line: BudgetLine
    let home: String
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { line.isIncluded }, set: { line.isIncluded = $0; line.includeOverridden = true }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.name).foregroundStyle(line.isIncluded ? .primary : .secondary).lineLimit(2)
                        if !line.note.isEmpty {
                            Text(line.note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(line.amount == 0 ? "Free" : Fmt.money(line.amount, line.currency))
                            .foregroundStyle(line.isIncluded ? .primary : .secondary)
                            .strikethrough(!line.isIncluded)
                        if line.autoKey != nil {
                            Text(line.amountEdited ? "your price" : "typical").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct CategoryLine: View {
    let category: BudgetCategory
    let planned: Double
    let spent: Double
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: category.symbol).foregroundStyle(Theme.color(for: category)).frame(width: 22)
                Text(category.label).font(.subheadline)
                Spacer()
                Text("\(Fmt.money(spent, currency)) / \(Fmt.money(planned, currency))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.color(for: category).opacity(0.15))
                    Capsule().fill(spent > planned && planned > 0 ? Color.red : Theme.color(for: category))
                        .frame(width: planned > 0 ? geo.size.width * min(1, spent / planned) : (spent > 0 ? geo.size.width : 0))
                }
            }
            .frame(height: 6)
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let home: String
    @EnvironmentObject private var rates: CurrencyService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.symbol)
                .frame(width: 32, height: 32)
                .background(Theme.color(for: expense.category).opacity(0.15), in: Circle())
                .foregroundStyle(Theme.color(for: expense.category))
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title.isEmpty ? expense.category.label : expense.title)
                Text("\(Fmt.day.string(from: expense.date)) \(CountryStore.shared.flag(expense.countryCode))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(expense.amount, expense.currency)).font(.subheadline.weight(.semibold))
                if expense.currency != home {
                    Text("≈ \(Fmt.money(rates.convert(expense.amount, from: expense.currency, to: home), home))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ExpenseEditor: View {
    let trip: Trip
    let expense: Expense?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var rates: CurrencyService

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var currency = "GBP"
    @State private var category: BudgetCategory = .food
    @State private var date = Date()
    @State private var countryCode = ""

    private static let quickCategories: [BudgetCategory] = [.accommodation, .food, .transport, .activities, .shopping, .other, .flights, .visas]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(title: "Amount", amount: $amount, currency: $currency)
                        .font(.title2)
                    if currency != trip.homeCurrency && amount > 0 {
                        Text("≈ \(Fmt.money(rates.convert(amount, from: currency, to: trip.homeCurrency), trip.homeCurrency))")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Category") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(Self.quickCategories) { c in
                            Button { category = c } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: c.symbol).font(.title3)
                                    Text(c.label.components(separatedBy: " ").first ?? c.label).font(.caption2).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(category == c ? Theme.color(for: c).opacity(0.25) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(category == c ? Theme.color(for: c) : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    TextField("What was it? (optional)", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Country", selection: $countryCode) {
                        Text("None").tag("")
                        ForEach(trip.countryCodesInRoute, id: \.self) { c in
                            Text("\(CountryStore.shared.flag(c)) \(CountryStore.shared.name(c))").tag(c)
                        }
                    }
                }
            }
            .navigationTitle(expense == nil ? "Log spending" : "Edit spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(amount <= 0)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let e = expense {
            title = e.title; amount = e.amount; currency = e.currency; category = e.category; date = e.date
            countryCode = e.countryCode ?? ""
        } else if let cur = trip.currentStop {
            countryCode = cur.countryCode
            currency = CountryStore.shared.country(cur.countryCode)?.mainCurrency ?? trip.homeCurrency
        } else {
            currency = trip.homeCurrency
        }
    }

    private func save() {
        let target = expense ?? {
            let e = Expense(title: title, category: category, amount: amount, currency: currency)
            e.trip = trip
            context.insert(e)
            return e
        }()
        target.title = title
        target.amount = amount
        target.currency = currency
        target.category = category
        target.date = date
        target.countryCode = countryCode.isEmpty ? nil : countryCode
        try? context.save()
        dismiss()
    }
}

struct BudgetLineEditor: View {
    let trip: Trip
    let line: BudgetLine?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var amount: Double = 0
    @State private var currency = "GBP"
    @State private var category: BudgetCategory = .flights

    private var isAuto: Bool { line?.autoKey != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isAuto {
                        Text(name).font(.headline)
                    } else {
                        TextField("Name (e.g. Flight to Bangkok)", text: $name)
                    }
                    AmountField(title: "Amount", amount: $amount, currency: $currency)
                    if !isAuto {
                        Picker("Category", selection: $category) {
                            ForEach(BudgetCategory.allCases) { c in Label(c.label, systemImage: c.symbol).tag(c) }
                        }
                    }
                } footer: {
                    if let note = line?.note, !note.isEmpty { Text(note) }
                }
                if isAuto, let line, line.amountEdited {
                    Section {
                        Button("Use the typical price again") {
                            line.amountEdited = false
                            BudgetSync.syncAutoLines(trip, context: context)
                            try? context.save()
                            dismiss()
                        }
                    }
                }
                if isAuto {
                    Section {
                        Link(destination: searchURL) { Label("Search current prices", systemImage: "safari") }
                    }
                }
            }
            .navigationTitle(line == nil ? "Fixed cost" : (isAuto ? "Typical cost" : "Edit cost"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let target = line ?? {
                            let l = BudgetLine(name: name, category: category, amount: amount, currency: currency)
                            l.trip = trip
                            context.insert(l)
                            return l
                        }()
                        if !isAuto {
                            target.name = name.isEmpty ? category.label : name
                            target.category = category
                        } else if target.amount != amount || target.currency != currency {
                            target.amountEdited = true
                        }
                        target.amount = amount
                        target.currency = currency
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                    .disabled(!isAuto && amount <= 0)
                }
            }
            .onAppear {
                currency = trip.homeCurrency
                if let line { name = line.name; amount = line.amount; currency = line.currency; category = line.category }
            }
        }
    }

    private var searchURL: URL {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: "\(name) price UK 2026")]
        return c.url!
    }
}

struct TotalBudgetEditor: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(trip.homeCurrency)
                        TextField("Total budget", value: $trip.totalBudget, format: .number.precision(.fractionLength(0)))
                            .keyboardType(.numberPad)
                            .font(.title2.bold())
                    }
                } footer: {
                    Text("Everything you have for the whole trip, including flights and insurance.")
                }
            }
            .navigationTitle("Total budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct ConverterView: View {
    let home: String
    @EnvironmentObject private var rates: CurrencyService
    @State private var amount: Double = 100
    @State private var from = "THB"
    @State private var to = "GBP"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(title: "Amount", amount: $amount, currency: $from).font(.title2)
                    HStack {
                        Text(Fmt.money(rates.convert(amount, from: from, to: to), to)).font(.title2.bold())
                        Spacer()
                        Picker("", selection: $to) {
                            ForEach(rates.knownCurrencies, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                    Button {
                        let t = from
                        from = to
                        to = t
                    } label: { Label("Swap", systemImage: "arrow.up.arrow.down") }
                }
                Section("Quick reference") {
                    ForEach([1.0, 5, 10, 20, 50, 100], id: \.self) { v in
                        HStack {
                            Text(Fmt.money(v, to))
                            Spacer()
                            Text(Fmt.money(rates.convert(v, from: to, to: from), from)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Converter")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { to = home }
        }
    }
}
