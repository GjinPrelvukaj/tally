import Foundation

extension Store {
    /// The demo: a made-up 19 October 2026 on the starter plan, in memory, so pictures never touch saved data.
    /// `setUp: false` is the first run. `paydayDue` moves to 1 November with the salary due and not yet added;
    /// `afterPayday` also adds it, split as planned.
    public static func demo(afterPayday: Bool, paydayDue: Bool = false, setUp: Bool = true,
                            calendar: Calendar = .current) -> (store: Store, today: Date) {
        let noon = { (month: Int, day: Int) in calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))! }
        let store = Store(inMemory: true, calendar: calendar)
        guard setUp else { return (store, noon(10, 19)) }
        let paidOnTheFirst = [Seed.ID.salary, Seed.ID.rent, Seed.ID.bills, Seed.ID.emergency, Seed.ID.pot]
        let paid = Dictionary(uniqueKeysWithValues: Seed.plan.filter { paidOnTheFirst.contains($0.id) }.map { ($0.id, $0.amount) })
        store.setUp(balances: [.main: .euros(640), .clothes: .euros(240), .emergency: .euros(2150), .card: .euros(-45)],
                    paid: paid, today: noon(10, 19))
        guard afterPayday || paydayDue else { return (store, noon(10, 19)) }
        let today = noon(11, 1)
        guard afterPayday else { return (store, today) }
        let ledger = store.ledger()
        if let salary = ledger.stillToPay(today: today).first(where: { $0.item.id == Seed.ID.salary }) {
            store.payday(salary, amount: salary.item.amount,
                         split: Dictionary(uniqueKeysWithValues: ledger.split(of: salary).map { ($0.id, $0.amount) }), at: today)
        }
        return (store, today)
    }
}
