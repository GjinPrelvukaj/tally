import SwiftUI

/// Who money is open with. The partner is `nil` among the people; elsewhere a person is their name.
enum Someone: Hashable {
    case new, partner, named(String)

    /// The name `Entry.person` keeps: nil for the partner.
    var person: String? {
        switch self {
        case .new, .partner: nil
        case .named(let name): name
        }
    }

    init(_ person: String?) { self = person.map(Someone.named) ?? .partner }
}

/// People: everyone money is open with, and how it stands ("Ben owes you 50,00 €", "You owe Ana 20,00 €", settled
/// last). A row opens the card to record more with them; Record opens it for anyone.
struct PeopleView: View {
    let store: Store
    let record: (Someone) -> Void
    @Environment(\.partnerName) private var partnerName

    var body: some View {
        let ledger = store.ledger()
        // The partner is listed once named, even before anything is open with them.
        let people = ledger.people + (!partnerName.isEmpty && !ledger.people.contains(nil) ? [nil] : [])
        let open = people.filter { ledger.owes($0) != .zero }, settled = people.filter { ledger.owes($0) == .zero }
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            HStack {
                Text("PEOPLE").eyebrow()
                Spacer()
                Button { record(.new) } label: { Label("Record", systemImage: "plus") }.buttonStyle(.secondary)
            }
            .padding(.bottom, Kit.Space.label)
            if people.isEmpty {
                Text("No one yet. Record money you lent or borrowed, or what someone owed you from before.")
                    .font(Kit.body).opacity(0.55).fixedSize(horizontal: false, vertical: true)
            }
            if !open.isEmpty { SettingsCard { ForEach(open, id: \.self) { row($0, ledger) } } }
            if !settled.isEmpty {
                Text("Settled").groupLabel().padding(.top, Kit.Space.item)
                SettingsCard { ForEach(settled, id: \.self) { row($0, ledger) } }.opacity(0.6)
            }
        }
        .frame(maxWidth: Kit.readable, alignment: .leading)
        .pane()
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func name(_ person: String?) -> String { person ?? (partnerName.isEmpty ? "Partner" : partnerName) }

    private func row(_ person: String?, _ ledger: Ledger) -> some View {
        let owes = ledger.owes(person)
        let name = name(person)
        let line = owes > .zero ? "\(name) owes you" : owes < .zero ? "You owe \(name)" : "Settled"
        return Button { record(Someone(person)) } label: {
            HStack(spacing: 12) {
                Text(name.prefix(1).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Kit.body)
                    Text(line).font(Kit.quiet).opacity(0.5)
                }
                Spacer(minLength: Kit.Space.item)
                if owes != .zero {
                    Text(Cents(abs(owes.value)).formatted).font(Kit.body.weight(.medium)).monospacedDigit()
                        .foregroundStyle(owes > .zero ? Color.arrived : .hex(0xFBBF24))
                        .privateAmount()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
