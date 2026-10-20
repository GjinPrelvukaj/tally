import Foundation
import SwiftData

/// The savings pots of the person's own, kept in the settings row: added, renamed, given a goal, retired or brought back.
extension Store {
    /// A new savings pot at the end, in the next colour free. Returns it.
    @discardableResult
    public func addPot(_ name: String) -> SavingsPot? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let settings = attempt({ try settings() }) ?? nil else { return nil }
        let pot = SavingsPot(name: name, colour: SavingsPot.nextColour(after: settings.savings.filter { !$0.retired }))
        settings.savings.append(pot)
        commit()
        return pot
    }

    /// A new name. Retiring is `retire`, so a pot is never hidden with money in it.
    public func rename(_ pot: Pot, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let settings = attempt({ try settings() }) ?? nil,
              let index = settings.savings.firstIndex(where: { $0.id == pot }) else { return }
        settings.savings[index].name = name
        commit()
    }

    /// What it saves up to; nil or 0 for nothing.
    public func setGoal(_ goal: Cents?, for pot: Pot) {
        guard let settings = attempt({ try settings() }) ?? nil else { return }
        settings.goalAmounts[pot] = goal.flatMap { $0 > .zero ? $0 : nil }
        commit()
    }

    /// No longer shown or offered; its entries keep it. Only when `Ledger.canRetire` says so. Categories that spent
    /// from it spend from Main.
    public func retire(_ pot: Pot) {
        guard let ledger = currentLedger(), ledger.canRetire(pot), let settings = attempt({ try settings() }) ?? nil,
              let index = settings.savings.firstIndex(where: { $0.id == pot }) else { return }
        settings.savings[index].retired = true
        for record in attempt({ try context.fetch(FetchDescriptor<CategoryRecord>()) }) ?? [] where record.pot == pot.rawValue {
            record.pot = Pot.main.rawValue
        }
        commit()
    }

    public func bringBack(_ pot: Pot) {
        guard let settings = attempt({ try settings() }) ?? nil,
              let index = settings.savings.firstIndex(where: { $0.id == pot }) else { return }
        settings.savings[index].retired = false
        commit()
    }
}
