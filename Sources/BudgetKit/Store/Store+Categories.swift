import Foundation
import SwiftData

extension Store {
    /// A new category at the end of the list. Returns it, so it can be chosen at once.
    @discardableResult
    public func addCategory(_ name: String, pot: Pot) -> Category? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let records = attempt({ try context.fetch(FetchDescriptor<CategoryRecord>()) }) else { return nil }
        let category = Category(name: name, pot: pot)
        context.insert(CategoryRecord(category, order: (records.map(\.order).max() ?? -1) + 1))
        commit()
        return category
    }

    /// A new name, another pot (for spends from now on: saved ones keep theirs), or retired / back again.
    public func update(_ category: Category) {
        let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let records = attempt({ try context.fetch(FetchDescriptor<CategoryRecord>()) }),
              let record = records.first(where: { $0.id == category.id }) else { return }
        var category = category
        category.name = name
        record.apply(category)
        commit()
    }
}
