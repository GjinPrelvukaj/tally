import Testing
import Foundation
@testable import BudgetKit

@MainActor @Suite struct CategoryAndPartnerTests {
    let oct19 = Fixtures.date(2026, 10, 19)

    func store() -> Store {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUpExample(balances: [.main: Cents(15000), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
                           paid: Example.paidInOctober, today: oct19)
        return store
    }

    @Test func aNewStoreHasTheFiveStarters() {
        #expect(store().ledger().categories == Category.starters)
    }

    @Test func aCategoryOfYourOwnIsKeptAndOffered() throws {
        let store = store()
        let smokes = try #require(store.addCategory("  Smokes ", pot: .main))
        #expect(smokes.name == "Smokes")
        #expect(store.ledger().categories.last == smokes)
        #expect(store.addCategory("   ", pot: .main) == nil)
    }

    @Test func renamingKeepsEverySpendsCategory() throws {
        let store = store()
        store.logSpend(Cents(340), category: .other, note: nil, paidWith: .bank, at: oct19)
        var other = Category.other
        other.name = "Smokes"
        store.update(other)
        let ledger = store.ledger()
        let spend = try #require(ledger.entries.last { $0.kind == .spend })
        #expect(ledger.category(spend.category)?.name == "Smokes")
    }

    @Test func movingACategoryToAnotherPotLeavesSavedSpendsWhereTheyWere() {
        let store = store()
        store.logSpend(Cents(1000), category: .food, note: nil, paidWith: .bank, at: oct19)
        var food = Category.food
        food.pot = .clothes
        store.update(food)
        #expect(store.ledger().balance(.main) == Cents(14000))
        #expect(store.ledger().balance(.clothes) == .zero)
        store.logSpend(Cents(1000), category: food, note: nil, paidWith: .bank, at: oct19)
        #expect(store.ledger().balance(.clothes) == Cents(-1000))
    }

    @Test func aRetiredCategoryStaysNamed() throws {
        let store = store()
        store.logSpend(Cents(500), category: .fragrance, note: nil, paidWith: .bank, at: oct19)
        var fragrance = Category.fragrance
        fragrance.retired = true
        store.update(fragrance)
        let ledger = store.ledger()
        #expect(ledger.categories.first { $0.id == "fragrance" }?.retired == true)
        #expect(ledger.category("fragrance")?.name == "Fragrance")
        // A key nobody knows any more still reads as something.
        #expect(ledger.category("gone")?.name == "Other")
    }

    @Test func theirPartIsHalfRoundedDownOrAll() {
        #expect(PartnerShare.with.theirs(of: Cents(1020)) == .zero)
        #expect(PartnerShare.half.theirs(of: Cents(1021)) == Cents(510))
        #expect(PartnerShare.forThem.theirs(of: Cents(1021)) == Cents(1021))
    }

    @Test func whatThePartnerOwesGoesUpWithPayBackAndDownWhenPaid() {
        let store = store()
        store.logSpend(Cents(1000), category: .goingOut, note: "coffee", paidWith: .bank, at: oct19, partner: .half, paysBack: true)
        store.logSpend(Cents(2400), category: .food, note: nil, paidWith: .bank, at: oct19, partner: .forThem, paysBack: true)
        // Together, but yours: nothing owed. Theirs, but a gift: nothing owed.
        store.logSpend(Cents(800), category: .goingOut, note: nil, paidWith: .bank, at: oct19, partner: .with, paysBack: true)
        store.logSpend(Cents(600), category: .food, note: nil, paidWith: .bank, at: oct19, partner: .forThem, paysBack: false)
        #expect(store.ledger().partnerOwes == Cents(2900))
        store.partnerPaidBack(Cents(1900), at: oct19)
        let ledger = store.ledger()
        #expect(ledger.partnerOwes == Cents(1000))
        // 150 − 10 − 24 − 8 − 6 + 19 back.
        #expect(ledger.balance(.main) == Cents(12100))
    }

    @Test func editingASpendCanAddOrDropThePartner() throws {
        let store = store()
        store.logSpend(Cents(1000), category: .goingOut, note: nil, paidWith: .bank, at: oct19)
        let spend = try #require(store.ledger().entries.last { $0.kind == .spend })
        var draft = EntryDraft(spend, ledger: store.ledger())
        draft.partner = .half
        draft.paysBack = true
        store.update(try #require(draft.entry))
        #expect(store.ledger().partnerOwes == Cents(500))
        draft.partner = .with
        store.update(try #require(draft.entry))
        #expect(store.ledger().partnerOwes == .zero)
    }
}

@MainActor @Suite struct PaymentMethodTests {
    let oct19 = Fixtures.date(2026, 10, 19)

    @Test func cashComesOutOfTheCategorysPotAndIsRemembered() throws {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUpExample(balances: [.main: Cents(15000), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
                           paid: Example.paidInOctober, today: oct19)
        store.logSpend(Cents(510), category: .food, note: "coffee", paidWith: .cash, at: oct19)
        store.logSpend(Cents(340), category: .other, note: nil, paidWith: .card, at: oct19)
        let ledger = store.ledger()
        #expect(ledger.balance(.main) == Cents(14490))
        #expect(ledger.balance(.card) == Cents(-6680))
        let coffee = try #require(ledger.entries.last { $0.note == "coffee" })
        #expect(coffee.method == .cash)
        #expect(EntryDraft(coffee, ledger: ledger).method == .cash)
    }

    @Test func aSpendSavedBeforeMethodsReadsAsBankOrCard() {
        let ledger = Fixtures.oct19(main: .euros(150))
        let onCard = Entry(date: oct19, amount: Cents(100), kind: .spend, from: .card, category: "food")
        let fromMain = Entry(date: oct19, amount: Cents(100), kind: .spend, from: .main, category: "food")
        #expect(EntryDraft(onCard, ledger: ledger).method == .card)
        #expect(EntryDraft(fromMain, ledger: ledger).method == .bank)
    }
}
