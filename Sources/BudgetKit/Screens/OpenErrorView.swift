import AppKit
import SwiftUI

/// When the saved data can't be opened: say so and where it is, and never start fresh over it.
public struct OpenErrorView: View {
    let path: String

    public init(path: String) { self.path = path }

    public var body: some View {
        VStack(spacing: Living.gap) {
            Text("Tally couldn't open your data").font(.title3.weight(.semibold))
            Text(path).font(Living.caption).opacity(0.45).multilineTextAlignment(.center).textSelection(.enabled)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(28)
        .frame(width: Glass.contentSize.width, height: Glass.contentSize.height)
        .background { Glass(light: [[.hex(0xFB7185), .hex(0xFBBF24), .hex(0xFB7185)]], position: 0) }
    }
}
