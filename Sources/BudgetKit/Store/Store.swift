import Foundation
import SwiftData
import Observation

/// Everything saved, on this Mac. The screens only talk to this: they read `ledger()` and call the actions.
/// Each action saves and bumps `revision`, so a view that read `ledger()` draws again.
@MainActor @Observable
public final class Store {
    public private(set) var isSetUp = false
    public private(set) var revision = 0
    /// Set when saving to disk failed, so the screens can say so instead of pretending.
    public private(set) var saveError: Error?
    /// Set when reading from disk failed. Not observed: `ledger()` runs while a view draws, and a read
    /// that fails must never be shown as an empty plan.
    @ObservationIgnored public private(set) var loadError: Error?

    /// The entries the last action wrote, so it can be taken back; one level only.
    public private(set) var undoable: [UUID] = []
    /// Goes up with every recording action (not with an undo), so the screens can offer "Undo" for a moment.
    public private(set) var recordings = 0
    public var canUndo: Bool { !undoable.isEmpty }

    /// Kept for as long as the store lives: a context does not keep its container alive.
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var cached: (revision: Int, ledger: Ledger)?

    /// `~/Library/Application Support/Budget/Budget.store`. The app is called Tally now, but the file keeps
    /// its first name: renaming it would make the app start empty on a Mac that already has data.
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Budget/Budget.store")
    }

    public init(inMemory: Bool, calendar: Calendar = .current) {
        precondition(inMemory, "use init(url:) to keep data on disk")
        // An in-memory container only fails if the model types are wrong, which the tests catch.
        container = try! Store.container(ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        self.context = ModelContext(container)
        self.calendar = calendar
        try! seedCategories()
    }

    public init(url: URL, calendar: Calendar = .current) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // `.none`: nothing can ever sync, whatever the app's entitlements say.
        container = try Store.container(ModelConfiguration(url: url, cloudKitDatabase: .none))
        self.context = ModelContext(container)
        self.calendar = calendar
        isSetUp = try settings() != nil
        try seedCategories()
    }

    public convenience init(calendar: Calendar = .current) throws {
        try self.init(url: Store.defaultURL, calendar: calendar)
    }

    private static func container(_ configuration: ModelConfiguration) throws -> ModelContainer {
        // Through the migration plan: a file saved by an older Tally is moved to the newest version as it opens.
        try ModelContainer(for: Schema(versionedSchema: SchemaV5.self), migrationPlan: TallyMigration.self, configurations: configuration)
    }

    /// The five starter categories, in a store that has none yet: a new one, or one saved before categories were kept.
    private func seedCategories() throws {
        guard try context.fetchCount(FetchDescriptor<CategoryRecord>()) == 0 else { return }
        for (order, category) in Category.starters.enumerated() { context.insert(CategoryRecord(category, order: order)) }
        try context.save()
    }

    /// A snapshot of everything, for all the money logic. Cached until the next action.
    /// If the disk cannot be read this is empty and `loadError` says why; actions then refuse to write.
    public func ledger() -> Ledger {
        currentLedger() ?? Ledger(start: [:], startMonth: YearMonth(.now, calendar: calendar), plan: [], entries: [], calendar: calendar)
    }

    /// The real ledger, or nil when it could not be read (never cached, so the next call tries again).
    func currentLedger() -> Ledger? {
        if let cached, cached.revision == revision { return cached.ledger }
        guard let ledger = attempt({ try loadLedger() }) else { return nil }
        cached = (revision, ledger)
        return ledger
    }

    private func loadLedger() throws -> Ledger {
        let settings = try settings()
        let plan = try context.fetch(FetchDescriptor<PlanItemRecord>(sortBy: [SortDescriptor(\.order)]))
        let entries = try context.fetch(FetchDescriptor<EntryRecord>(sortBy: [SortDescriptor(\.date)]))
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>(sortBy: [SortDescriptor(\.order)]))
        return Ledger(start: settings?.balances ?? [:], startMonth: settings?.month ?? YearMonth(.now, calendar: calendar),
                      plan: plan.map(\.value), entries: entries.map(\.value), calendar: calendar,
                      categories: categories.map(\.value), savings: settings?.savings ?? SavingsPot.original,
                      goals: settings?.goalAmounts ?? [:])
    }

    func settings() throws -> SettingsRecord? {
        try context.fetch(FetchDescriptor<SettingsRecord>()).first
    }

    /// Runs a read; a failure is remembered in `loadError` and gives nil, a success clears it.
    func attempt<T>(_ read: () throws -> T) -> T? {
        do {
            let value = try read()
            loadError = nil
            return value
        } catch {
            loadError = error
            return nil
        }
    }

    /// Saves and tells the screens something changed.
    func commit() {
        do {
            try context.save()
            saveError = nil
        } catch {
            saveError = error
        }
        revision += 1
    }

    // MARK: Actions. Money is added as entries; only the last action can be taken back (`undo`).
    /// First run: the balances now, the seeded plan, and what was already paid this month.
    /// `paid` are plan items paid before the first run: done, but the balances typed in already include them.
    public func setUp(balances: [Pot: Cents], paid: [UUID: Cents], today: Date,
                      plan: [PlanItem] = Seed.plan, goals: [Pot: Cents] = Seed.goals, savings: [SavingsPot] = SavingsPot.original) {
        // Also look at the disk: a store that already holds settings must never be seeded again.
        guard !isSetUp, attempt({ try context.fetchCount(FetchDescriptor<SettingsRecord>()) }) == 0 else { return }
        let month = YearMonth(today, calendar: calendar)
        context.insert(SettingsRecord(balances: balances, startMonth: month, goals: goals, savings: savings))
        // A starting category in a pot this person doesn't have (Clothes) spends from Main instead.
        for record in attempt({ try context.fetch(FetchDescriptor<CategoryRecord>()) }) ?? []
        where Pot(record.pot).isSavings && !savings.contains(where: { $0.id.rawValue == record.pot }) {
            record.pot = Pot.main.rawValue
        }
        for (order, item) in plan.enumerated() { context.insert(PlanItemRecord(item, order: order)) }
        for entry in Seed.paidEntries(paid, plan: plan, month: month, at: today) { context.insert(EntryRecord(entry)) }
        isSetUp = true
        commit()
    }

    /// A spend. On the credit card the debt grows; by bank card or cash it comes out of the category's pot. With the partner, it
    /// says how; `paysBack` adds their part to what they owe.
    public func logSpend(_ amount: Cents, category: Category, note: String?, paidWith method: PaymentMethod, at date: Date,
                         partner: PartnerShare? = nil, paysBack: Bool = false) {
        guard amount > .zero else { return }
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let theirs = partner?.theirs(of: amount) ?? .zero
        add(Entry(date: date, amount: amount, kind: .spend, from: category.pot(paidWith: method), category: category.id,
                  note: note?.isEmpty == false ? note : nil, partner: partner, owed: paysBack && theirs > .zero ? theirs : nil, method: method))
    }

    /// Money with a person (nil: the partner): `lent` and `paidBack` go out of `pot`, `repayment` and `borrowed` come
    /// into it. `before`: it happened before Tally, so it is owed but moves no money now.
    public func record(_ kind: EntryKind, _ amount: Cents, with person: String?, pot: Pot = .main, before: Bool = false, at date: Date) {
        let name = person?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > .zero, name?.isEmpty != true, kind.isWithSomeone else { return }
        let out = kind == .lent || kind == .paidBack
        add(Entry(date: date, amount: amount, kind: kind, from: out ? pot : nil, to: out ? nil : pot,
                  movesMoney: !before, person: name))
    }

    /// Paid, at the amount actually paid. A transfer moves money `from` to `to`; a payment leaves `from`.
    public func markPaid(_ due: Due, amount: Cents, at date: Date) {
        guard amount > .zero, isOpen(due), let entry = entry(for: due.item, month: due.month, amount: amount, at: date) else { return }
        add(entry)
    }

    /// The income arrived, and each item chosen to be paid out of it was paid at its own amount.
    /// An item already done that month (paid early, or dismissed) is left out, so nothing is paid twice;
    /// so is one at 0, which stays due (and held back, as the income has come).
    public func payday(_ income: Due, amount: Cents, split: [UUID: Cents], at date: Date) {
        guard amount > .zero, let ledger = currentLedger(), !ledger.isDone(income.item.id, in: income.month) else { return }
        var entries = [entry(for: income.item, month: income.month, amount: amount, at: date)]
        for item in ledger.plan where !ledger.isDone(item.id, in: income.month) {
            if let paid = split[item.id], paid > .zero { entries.append(entry(for: item, month: income.month, amount: paid, at: date)) }
        }
        record(entries.compactMap { $0 })
    }

    /// Takes back what the last action wrote. Plan edits in between do not matter: it goes by the entries' ids.
    public func undo() {
        guard canUndo, let records = attempt({ try context.fetch(FetchDescriptor<EntryRecord>()) }) else { return }
        records.filter { undoable.contains($0.id) }.forEach(context.delete)
        undoable = []
        commit()
    }

    /// "Not this month": done, with no money moving.
    public func dismiss(_ due: Due, at date: Date) {
        guard isOpen(due) else { return }
        add(Entry(date: date, amount: .zero, kind: .dismissed, planItem: due.item.id, forMonth: due.month, movesMoney: false))
    }

    /// Puts a pot right. The difference is written down as an adjustment, so nothing is hidden.
    public func setBalance(_ pot: Pot, to target: Cents, at date: Date) {
        guard let current = currentLedger()?.balance(pot), target != current else { return }
        let difference = target - current
        add(Entry(date: date, amount: difference, kind: .adjustment, to: pot))
    }

    /// Writes an edited entry over the saved one. Zero is never saved as money moved.
    public func update(_ entry: Entry) {
        guard entry.amount > .zero || entry.kind == .adjustment,
              let records = attempt({ try context.fetch(FetchDescriptor<EntryRecord>()) }),
              let record = records.first(where: { $0.id == entry.id }) else { return }
        holdSetBalances(changing: record.value, to: entry, in: records)
        record.apply(entry)
        commit()
    }

    /// Gone, as if it never happened: a paid plan item is due again. A balance set after it stays as it was set.
    public func deleteEntry(_ id: UUID) {
        guard let records = attempt({ try context.fetch(FetchDescriptor<EntryRecord>()) }) else { return }
        if let record = records.first(where: { $0.id == id }) { holdSetBalances(changing: record.value, to: nil, in: records) }
        records.filter { $0.id == id }.forEach(context.delete)
        // Undo goes by the ids of the last action; with one of them gone it no longer takes back all of it.
        if undoable.contains(id) { undoable = [] }
        commit()
    }

    /// Writes the set balances `Ledger.setBalancesHeld` changes, so a pot set by hand still shows what was set.
    private func holdSetBalances(changing old: Entry, to new: Entry?, in records: [EntryRecord]) {
        guard let ledger = currentLedger() else { return }
        for set in ledger.setBalancesHeld(changing: old, to: new) {
            records.first { $0.id == set.id }?.apply(set)
        }
    }

    /// Adds a new plan item at the end, or replaces an existing one in its place.
    public func save(_ item: PlanItem) {
        guard let records = attempt({ try context.fetch(FetchDescriptor<PlanItemRecord>()) }) else { return }
        if let record = records.first(where: { $0.id == item.id }) {
            if record.value.kind == .income && item.kind != .income { records.forEach { $0.stopWaiting(on: item.id) } }
            record.apply(item)
        } else {
            context.insert(PlanItemRecord(item, order: (records.map(\.order).max() ?? -1) + 1))
        }
        commit()
    }

    /// Entries that point at the item stay, so history and balances do not change. Items that waited for it become "any day".
    public func delete(_ item: UUID) {
        guard let records = attempt({ try context.fetch(FetchDescriptor<PlanItemRecord>()) }) else { return }
        records.forEach { $0.stopWaiting(on: item) }
        records.filter { $0.id == item }.forEach(context.delete)
        commit()
    }

    /// Still waiting for that month. A double-click or a second tap must never record it twice;
    /// a ledger that can't be read counts as not open, so nothing is written blind.
    private func isOpen(_ due: Due) -> Bool {
        currentLedger()?.isDone(due.item.id, in: due.month) == false
    }

    func add(_ entry: Entry) { record([entry]) }

    /// One action's entries, written and remembered for `undo`.
    private func record(_ entries: [Entry]) {
        for entry in entries { context.insert(EntryRecord(entry)) }
        undoable = entries.map(\.id)
        recordings += 1
        commit()
    }

    private func entry(for item: PlanItem, month: YearMonth, amount: Cents, at date: Date) -> Entry? {
        guard let kind = item.kind.entryKind else { return nil }
        return Entry(date: date, amount: amount, kind: kind, from: item.from, to: item.to, planItem: item.id, forMonth: month)
    }
}
