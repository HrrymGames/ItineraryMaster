import SwiftUI
import SwiftData
import Charts
import ItineraryCore

struct BudgetView: View {
    @Bindable var trip: Trip
    @EnvironmentObject private var rates: CurrencyService
    @Environment(\.modelContext) private var context
    @Query private var notes: [CountryNote]

    @State private var addingExpense = false
    @State private var editingExpense: Expense?
    @State private var addingLine = false
    @State private var editingLine: BudgetLine?
    @State private var editingBudget = false
    @State private var showConverter = false

    private var home: String { trip.homeCurrency }

    private func dailyRate(_ code: String) -> Double {
        if let r = notes.first(where: { $0.countryCode == code })?.dailyRate { return r }
        return CountryStore.shared.defaultDailyRate(for: code, in: home, rates: rates.rates).rounded()
    }

    private var countryNights: [(code: String, nights: Int)] {
        var order: [String] = []
        var nights: [String: Int] = [:]
        for s in trip.activeStops {
            let c = s.countryCode.isEmpty ? "??" : s.countryCode
            if nights[c] == nil { order.append(c) }
            nights[c, default: 0] += s.nights
        }
        return order.map { ($0, nights[$0] ?? 0) }
    }

    private var transportFixed: [FixedCost] {
        trip.activeStops.filter { $0.transportCost > 0 }.map {
            FixedCost(category: $0.transportMode == .flight ? .flights : .transport, cost: Money($0.transportCost, home), countryCode: $0.countryCode)
        }
    }

    private var bookedTotal: Double {
        trip.stops.flatMap(\.items).filter { $0.isBooked && $0.price > 0 }
            .reduce(0) { $0 + rates.convert($1.price, from: $1.currency, to: home) }
    }

    private var summary: BudgetSummary {
        let stays = countryNights.map { PlannedStay(countryCode: $0.code, nights: $0.nights, dailyRate: Money(dailyRate($0.code), home)) }
        let fixed = trip.budgetLines.map { FixedCost(category: $0.category, cost: Money($0.amount, $0.currency), countryCode: $0.countryCode) } + transportFixed
        let spent = trip.expenses.map { SpentItem(category: $0.category, cost: Money($0.amount, $0.currency), date: $0.date, countryCode: $0.countryCode) }
        return BudgetCalculator.summarize(currency: home, totalBudget: trip.totalBudget, stays: stays, fixed: fixed, spent: spent,
                                          rates: rates.rates, today: max(Date(), trip.startDate), tripEnd: trip.endDate)
    }

    var body: some View {
        NavigationStack {
            let s = summary
            List {
                Section {
                    overview(s)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Section {
                    HStack(spacing: 10) {
                        StatTile(title: "Planned total", value: Fmt.money(s.plannedTotal, home), caption: "\(Fmt.money(s.plannedPerDay, home))/day avg")
                        StatTile(title: s.planHeadroom >= 0 ? "Plan is under by" : "Plan is over by",
                                 value: Fmt.money(abs(s.planHeadroom), home),
                                 tint: s.planHeadroom >= 0 ? .green : .red)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    if s.plannedTotal > 0 {
                        Chart(BudgetCategory.allCases.filter { (s.plannedByCategory[$0] ?? 0) > 0 }) { c in
                            SectorMark(angle: .value("Amount", s.plannedByCategory[c] ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                                .foregroundStyle(Theme.color(for: c))
                                .cornerRadius(3)
                        }
                        .frame(height: 180)
                        .chartBackground { _ in
                            VStack {
                                Text("Plan").font(.caption).foregroundStyle(.secondary)
                                Text(Fmt.money(s.plannedTotal, home)).font(.headline)
                            }
                        }
                        ForEach(BudgetCategory.allCases.filter { (s.plannedByCategory[$0] ?? 0) > 0 || (s.spentByCategory[$0] ?? 0) > 0 }) { c in
                            CategoryLine(category: c, planned: s.plannedByCategory[c] ?? 0, spent: s.spentByCategory[c] ?? 0, currency: home)
                        }
                    }
                } header: {
                    Text("The plan")
                } footer: {
                    Text("Daily living costs (beds, food, local transport, activities) are nights × each country's daily budget. Booked so far: \(Fmt.money(bookedTotal, home)).")
                }

                Section {
                    if countryNights.isEmpty {
                        Text("Add stops to your route to see costs per country.").foregroundStyle(.secondary)
                    }
                    ForEach(countryNights, id: \.code) { row in
                        NavigationLink { CountryDetailView(code: row.code) } label: {
                            HStack {
                                Text(CountryStore.shared.flag(row.code))
                                VStack(alignment: .leading) {
                                    Text(CountryStore.shared.name(row.code))
                                    Text("\(Fmt.nights(row.nights)) × \(Fmt.money(dailyRate(row.code), home))/day")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(Fmt.money(Double(row.nights) * dailyRate(row.code), home)).font(.subheadline.weight(.semibold))
                                    if let spent = s.spentByCountry[row.code], spent > 0 {
                                        Text("spent \(Fmt.money(spent, home))").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Daily costs by country")
                } footer: {
                    Text("Tap a country to change its daily budget.")
                }

                Section {
                    ForEach(trip.budgetLines.sorted { $0.amount > $1.amount }) { line in
                        Button { editingLine = line } label: {
                            HStack {
                                Image(systemName: line.category.symbol).foregroundStyle(Theme.color(for: line.category)).frame(width: 24)
                                Text(line.name).foregroundStyle(.primary)
                                Spacer()
                                Text(Fmt.money(line.amount, line.currency)).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { context.delete(line); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    let legs = transportFixed.reduce(0) { $0 + $1.cost.amount }
                    if legs > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.swap").foregroundStyle(.cyan).frame(width: 24)
                            Text("Travel between stops (from route)")
                            Spacer()
                            Text(Fmt.money(legs, home)).foregroundStyle(.secondary)
                        }
                    }
                    Button { addingLine = true } label: { Label("Add fixed cost", systemImage: "plus") }
                } header: {
                    Text("Fixed costs")
                } footer: {
                    Text("Flights, insurance, gear, visas - one-off costs.")
                }

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
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingExpense = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $addingExpense) { ExpenseEditor(trip: trip, expense: nil) }
            .sheet(item: $editingExpense) { e in ExpenseEditor(trip: trip, expense: e) }
            .sheet(isPresented: $addingLine) { BudgetLineEditor(trip: trip, line: nil) }
            .sheet(item: $editingLine) { l in BudgetLineEditor(trip: trip, line: l) }
            .sheet(isPresented: $showConverter) { ConverterView(home: home).presentationDetents([.medium]) }
            .sheet(isPresented: $editingBudget) { TotalBudgetEditor(trip: trip).presentationDetents([.medium]) }
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
                         caption: s.daysLeft > 0 ? "for \(s.daysLeft) days" : nil,
                         tint: s.dailyAllowance >= s.plannedPerDay * 0.8 ? .green : .orange)
            }
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

    private let quickCategories: [BudgetCategory] = [.accommodation, .food, .transport, .activities, .shopping, .other, .flights, .visas]

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
                        ForEach(quickCategories) { c in
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

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Flight to Bangkok)", text: $name)
                AmountField(title: "Amount", amount: $amount, currency: $currency)
                Picker("Category", selection: $category) {
                    ForEach(BudgetCategory.allCases) { c in Label(c.label, systemImage: c.symbol).tag(c) }
                }
            }
            .navigationTitle(line == nil ? "Fixed cost" : "Edit cost")
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
                        target.name = name.isEmpty ? category.label : name
                        target.amount = amount
                        target.currency = currency
                        target.category = category
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                    .disabled(amount <= 0)
                }
            }
            .onAppear {
                currency = trip.homeCurrency
                if let line { name = line.name; amount = line.amount; currency = line.currency; category = line.category }
            }
        }
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
