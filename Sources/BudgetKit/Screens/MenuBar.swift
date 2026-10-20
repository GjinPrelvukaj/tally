import AppKit
import SwiftUI

/// Tally in the menu bar: what can be spent today beside the ring's symbol, and a click opens Quick log in a small panel,
/// so a spend is logged without bringing the window forward. With the lock on it shows nothing of the money and only
/// opens Tally, so it never gets round Touch ID; with amounts hidden the amount is left out.
public struct MenuBarLabel: View {
    let store: Store
    let today: () -> Date
    /// The real app, not the demo: only it reads the lock and hidden amounts from the settings.
    let real: Bool
    @AppStorage(Preference.lock) private var lockOn = false
    @AppStorage(Preference.amountsHidden) private var hidden = false

    public init(store: Store, today: @escaping () -> Date, real: Bool) {
        self.store = store
        self.today = today
        self.real = real
    }

    public var body: some View {
        // ponytail: read when the store changes, not at midnight; the next log or opening the panel brings it up to date.
        let shows = !(real && (lockOn || hidden)) && store.loadError == nil
        if shows, let allowance = store.ledger().allowance(today: today()) {
            Label(allowance.perDay.short, systemImage: "circle.dotted")
                .labelStyle(.titleAndIcon)
        } else {
            Image(systemName: "circle.dotted")
        }
    }
}

/// The panel under the menu bar item: Quick log, and a way to open Tally. Locked, only the way to open Tally.
public struct MenuBarPanel: View {
    let store: Store
    let today: () -> Date
    let real: Bool
    let demoPartner: String
    @AppStorage(Preference.lock) private var lockOn = false
    @AppStorage(Preference.partnerName) private var savedPartner = ""
    @Environment(\.openWindow) private var openWindow

    public init(store: Store, today: @escaping () -> Date, real: Bool, demoPartner: String = "") {
        self.store = store
        self.today = today
        self.real = real
        self.demoPartner = demoPartner
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            if (real && lockOn) || !store.isSetUp || store.loadError != nil {
                Text(real && lockOn ? "Tally is locked." : "Open Tally to start.").font(Kit.body).opacity(0.7)
            } else {
                let choices = QuickLogSheet.choices(store.ledger())
                QuickLogSheet(categories: choices.categories, last: choices.last, log: log, cancel: closePanel)
                    .environment(\.partnerName, real ? savedPartner : demoPartner)
                    // A new panel each time it opens, so it starts empty on the category used last.
                    .id(store.recordings)
            }
            Button("Open Tally", action: openTally).buttonStyle(.quiet)
        }
        .padding(Kit.Space.edge)
        .padding(.bottom, Glass.lightRoom - Kit.Space.edge)
        .frame(width: 380)
        // The window's own black glass and Today's light, whatever the Mac's appearance, as the design is drawn for it.
        .background { Glass(light: [Screen.today.light], position: 0) }
        .environment(\.colorScheme, .dark)
    }

    private func log(_ spend: LoggedSpend) {
        store.logSpend(spend.amount, category: spend.category, note: spend.note, paidWith: spend.method, at: today(),
                       partner: spend.partner, paysBack: spend.paysBack)
        closePanel()
    }

    private func openTally() {
        closePanel()
        openWindow(id: "budget")
        NSApp.activate()
    }

    /// The panel is the key window while it is open; closing it is how a menu bar panel goes away.
    private func closePanel() { NSApp.keyWindow?.close() }
}
