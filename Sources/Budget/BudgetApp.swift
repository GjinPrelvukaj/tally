import AppKit
import BudgetKit
import SwiftUI

/// One window is the whole app, so closing it quits.
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct BudgetApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    /// The store, or why it couldn't be opened: a store that fails never becomes a fresh one.
    private let opened: Result<Store, Error>
    private let today: () -> Date
    private let screen: Screen
    /// `--screen payday|log`: Today with that card open. `--screen firstrun`: a demo not yet set up.
    private let sheet: OpenSheet?
    /// Amounts start hidden: as the setting says, or `--hidden` in the demo (which never reads the real app's settings).
    private let hidden: Bool
    private let demo: Bool

    init() {
        let args = CommandLine.arguments
        // Otherwise AppKit takes a word like `pots` in `--demo --screen pots` for a file to open, and opens no window.
        UserDefaults.standard.register(defaults: ["NSTreatUnknownArgumentsAsOpen": "NO"])
        // `--demo`: a made-up 19 October in memory, today pinned, so pictures never touch the saved data.
        let named = args.firstIndex(of: "--screen").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        if args.contains("--demo") {
            let demo = Store.demo(afterPayday: args.contains("--after-payday"), paydayDue: named == "payday", setUp: named != "firstrun")
            opened = .success(demo.store)
            let pinned = demo.today
            today = { pinned }
        } else {
            opened = Result { try Store() }
            today = { Date() }
        }
        screen = named.flatMap(Screen.init(named:)) ?? .today
        sheet = named.flatMap(OpenSheet.init(rawValue:))
        demo = args.contains("--demo")
        hidden = demo ? args.contains("--hidden")
            : AmountsOnOpen.saved(in: .standard).startsHidden(lastHidden: UserDefaults.standard.bool(forKey: Preference.amountsHidden))
    }

    var body: some Scene {
        Window("Tally", id: "budget") {
            Group {
                switch opened {
                case .success(let store): RootView(store: store, today: today, screen: screen, sheet: sheet, hidden: hidden,
                                                     real: !demo,
                                                     demoPartner: "Sam")
                case .failure: OpenErrorView(path: Store.defaultURL.path)
                }
            }
            .containerBackground(.clear, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(WindowSize.standard)
        .windowResizability(.contentMinSize)
        .windowBackgroundDragBehavior(.enabled)

        // Quick log from the menu bar while Tally runs; none when the data couldn't be opened.
        MenuBarExtra(isInserted: .constant(store != nil)) {
            if let store { MenuBarPanel(store: store, today: today, real: !demo, demoPartner: "Sam") }
        } label: {
            if let store { MenuBarLabel(store: store, today: today, real: !demo) }
        }
        .menuBarExtraStyle(.window)
    }

    private var store: Store? { try? opened.get() }
}
