import SwiftUI
import SwiftData
import ItineraryCore

struct PackingView: View {
    let trip: Trip
    @Environment(\.modelContext) private var context
    @Query(sort: \PackingList.order) private var lists: [PackingList]
    @Query(sort: \ChecklistItem.createdAt) private var checklist: [ChecklistItem]
    @State private var segment = 0
    @State private var newListName = ""
    @State private var showNewList = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Packing lists").tag(0)
                    Text("To-do before I go").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if segment == 0 {
                    listsView
                } else {
                    ChecklistView(items: checklist)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Packing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if segment == 0 {
                        Button { showNewList = true } label: { Image(systemName: "plus.circle.fill") }
                    }
                }
            }
            .alert("New list", isPresented: $showNewList) {
                TextField("e.g. Ski trip, Festival", text: $newListName)
                Button("Create") {
                    let l = PackingList(name: newListName.isEmpty ? "New list" : newListName, order: lists.count)
                    context.insert(l)
                    try? context.save()
                    newListName = ""
                }
                Button("Cancel", role: .cancel) { newListName = "" }
            }
        }
    }

    private var listsView: some View {
        List {
            if lists.isEmpty {
                ContentUnavailableView("No packing lists", systemImage: "backpack", description: Text("Tap + to make one."))
            }
            let allItems = lists.flatMap(\.items)
            if !allItems.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        StatTile(title: "Packed", value: "\(allItems.filter(\.isPacked).count)/\(allItems.count)")
                        StatTile(title: "Weight", value: weightText(allItems.filter { $0.weightGrams > 0 }.reduce(0) { $0 + $1.weightGrams * max(1, $1.quantity) }))
                        StatTile(title: "To buy", value: Fmt.money(allItems.filter(\.needToBuy).reduce(0) { $0 + $1.price * Double(max(1, $1.quantity)) }, "GBP"))
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            ForEach(lists) { list in
                NavigationLink { PackingListDetailView(list: list, trip: trip) } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                            Circle().trim(from: 0, to: list.progress)
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: list.symbol).font(.caption).foregroundStyle(Theme.accent)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(list.name).font(.headline)
                            Text("\(list.packedCount) of \(list.items.count) packed").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { idx in
                for i in idx { context.delete(lists[i]) }
                try? context.save()
            }
        }
    }

    private func weightText(_ grams: Int) -> String {
        grams >= 1000 ? String(format: "%.1f kg", Double(grams) / 1000) : "\(grams) g"
    }
}

struct PackingListDetailView: View {
    @Bindable var list: PackingList
    let trip: Trip
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var app: AppState
    @State private var editing: PackingItem?
    @State private var adding = false
    @State private var hidePacked = false
    @State private var quickAdd = ""

    private var categories: [String] {
        var seen = Set<String>()
        return list.items.sorted { $0.createdAt < $1.createdAt }.map(\.category).filter { seen.insert($0).inserted }
    }

    var body: some View {
        List {
            Section {
                ProgressView(value: list.progress) {
                    Text("\(list.packedCount) of \(list.items.count) packed")
                }
                .tint(Theme.accent)
                HStack {
                    TextField("Quick add item…", text: $quickAdd)
                        .onSubmit(addQuick)
                    Button(action: addQuick) { Image(systemName: "plus.circle.fill") }
                        .disabled(quickAdd.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            ForEach(categories, id: \.self) { cat in
                let items = list.items.filter { $0.category == cat && (!hidePacked || !$0.isPacked) }.sorted { $0.createdAt < $1.createdAt }
                if !items.isEmpty {
                    Section(cat) {
                        ForEach(items) { item in
                            PackingItemRow(item: item) { editing = item }
                                .swipeActions {
                                    Button(role: .destructive) { context.delete(item); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Toggle("Hide packed", isOn: $hidePacked)
                    Button { for i in list.items { i.isPacked = false } } label: { Label("Unpack all (repack)", systemImage: "arrow.counterclockwise") }
                    Button { addNeedToBuyToBudget() } label: { Label("Add 'to buy' total to budget", systemImage: "sterlingsign.circle") }
                    Button("Rename list") { renameText = list.name; renaming = true }
                } label: { Image(systemName: "ellipsis.circle") }
                Button { adding = true } label: { Image(systemName: "plus.circle.fill") }
            }
        }
        .sheet(item: $editing) { item in PackingItemEditor(list: list, item: item) }
        .sheet(isPresented: $adding) { PackingItemEditor(list: list, item: nil) }
        .alert("Rename list", isPresented: $renaming) {
            TextField("Name", text: $renameText)
            Button("Save") { if !renameText.isEmpty { list.name = renameText } }
            Button("Cancel", role: .cancel) {}
        }
    }

    @State private var renaming = false
    @State private var renameText = ""

    private func addQuick() {
        let name = quickAdd.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let item = PackingItem(name: name, category: categories.first ?? "Other")
        item.list = list
        context.insert(item)
        try? context.save()
        quickAdd = ""
    }

    private func addNeedToBuyToBudget() {
        let total = list.items.filter(\.needToBuy).reduce(0) { $0 + $1.price * Double(max(1, $1.quantity)) }
        guard total > 0 else {
            app.flash("No 'to buy' items with prices yet")
            return
        }
        let line = BudgetLine(name: "Gear: \(list.name)", category: .gear, amount: total, currency: "GBP")
        line.trip = trip
        context.insert(line)
        try? context.save()
        app.flash("Added \(Fmt.money(total, "GBP")) to your budget")
    }
}

struct PackingItemRow: View {
    @Bindable var item: PackingItem
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { item.isPacked.toggle() }
            } label: {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPacked ? Theme.visited : .secondary)
            }
            .buttonStyle(.borderless)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).strikethrough(item.isPacked, color: .secondary)
                        .foregroundStyle(item.isPacked ? .secondary : .primary)
                    if item.quantity > 1 { Text("×\(item.quantity)").font(.caption).foregroundStyle(.secondary) }
                }
                HStack(spacing: 6) {
                    if item.needToBuy { Text("TO BUY").font(.system(size: 9, weight: .heavy)).foregroundStyle(.orange) }
                    if item.price > 0 { Text(Fmt.money(item.price, "GBP")) }
                    if item.weightGrams > 0 { Text("\(item.weightGrams) g") }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let url = item.link.asURL {
                Link(destination: url) { Image(systemName: "link") }.buttonStyle(.borderless)
            }
            Button(action: onEdit) { Image(systemName: "info.circle") }.buttonStyle(.borderless)
        }
    }
}

struct PackingItemEditor: View {
    let list: PackingList
    let item: PackingItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PackingList.order) private var lists: [PackingList]

    @State private var name = ""
    @State private var category = "Other"
    @State private var quantity = 1
    @State private var link = ""
    @State private var price: Double = 0
    @State private var weight = 0
    @State private var needToBuy = false
    @State private var targetListID: UUID?

    private var existingCategories: [String] {
        var seen = Set<String>()
        return lists.flatMap(\.items).map(\.category).filter { seen.insert($0).inserted }.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item", text: $name)
                    HStack {
                        TextField("Category", text: $category)
                        Menu {
                            ForEach(existingCategories, id: \.self) { c in Button(c) { category = c } }
                        } label: { Image(systemName: "chevron.up.chevron.down") }
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...50)
                    Picker("List", selection: $targetListID) {
                        ForEach(lists) { l in Text(l.name).tag(UUID?.some(l.id)) }
                    }
                }
                Section("Shopping") {
                    Toggle("Still need to buy", isOn: $needToBuy)
                    HStack {
                        Text("Price (GBP)")
                        Spacer()
                        TextField("0", value: $price, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 100)
                    }
                    TextField("Product link (Amazon, TikTok Shop…)", text: $link)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Weight") {
                    HStack {
                        Text("Grams")
                        Spacer()
                        TextField("0", value: $weight, format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 100)
                    }
                }
            }
            .navigationTitle(item == nil ? "Add item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                targetListID = list.id
                if let item {
                    name = item.name; category = item.category; quantity = item.quantity; link = item.link
                    price = item.price; weight = item.weightGrams; needToBuy = item.needToBuy
                } else {
                    category = list.items.last?.category ?? "Other"
                }
            }
        }
    }

    private func save() {
        let target = item ?? {
            let i = PackingItem(name: name)
            context.insert(i)
            return i
        }()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.category = category.trimmingCharacters(in: .whitespaces).isEmpty ? "Other" : category
        target.quantity = quantity
        target.link = link
        target.price = price
        target.weightGrams = weight
        target.needToBuy = needToBuy
        target.list = lists.first { $0.id == targetListID } ?? list
        try? context.save()
        dismiss()
    }
}

struct ChecklistView: View {
    let items: [ChecklistItem]
    @Environment(\.modelContext) private var context
    @State private var newTitle = ""
    @State private var newGroup = "Before I go"

    private var groups: [String] {
        var seen = Set<String>()
        return items.map(\.group).filter { seen.insert($0).inserted }
    }

    var body: some View {
        List {
            Section {
                let done = items.filter(\.isDone).count
                ProgressView(value: items.isEmpty ? 0 : Double(done) / Double(items.count)) {
                    Text("\(done) of \(items.count) done")
                }
                .tint(Theme.accent)
                HStack {
                    TextField("Add a to-do…", text: $newTitle).onSubmit(add)
                    Menu {
                        ForEach(groups + ["Before I go"], id: \.self) { g in Button(g) { newGroup = g } }
                    } label: { Text(newGroup).font(.caption).lineLimit(1) }
                    Button(action: add) { Image(systemName: "plus.circle.fill") }
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            ForEach(groups, id: \.self) { g in
                Section(g) {
                    ForEach(items.filter { $0.group == g }) { item in
                        ChecklistRow(item: item)
                            .swipeActions {
                                Button(role: .destructive) { context.delete(item); try? context.save() } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private func add() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        context.insert(ChecklistItem(title: t, group: newGroup))
        try? context.save()
        newTitle = ""
    }
}

struct ChecklistRow: View {
    @Bindable var item: ChecklistItem
    var body: some View {
        Button {
            withAnimation(.snappy) { item.isDone.toggle() }
        } label: {
            HStack {
                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.isDone ? Theme.visited : .secondary)
                    .font(.title3)
                Text(item.title).strikethrough(item.isDone).foregroundStyle(item.isDone ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}
