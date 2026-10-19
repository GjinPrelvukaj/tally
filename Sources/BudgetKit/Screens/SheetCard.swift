import SwiftUI

extension View {
    /// The glass every sheet sits on: black, a hairline round it, light along its bottom edge.
    func sheetCard(light: [Color] = [.arrived, Pot.main.light, .arrived]) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            ZStack {
                shape.fill(.black)
                EdgeLight(colors: light)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// A plain field that reads as editable: a faint capsule behind it, red text while `valid` is false.
/// The font is set on the field itself: from outside, a large one is drawn clipped to a small field.
struct GlassField: View {
    let label: String
    @Binding var text: String
    /// The big amount at the top of a sheet: larger type and more room round it.
    var large = false
    var align: TextAlignment = .trailing
    var valid = true
    /// Shown faintly while empty: what goes here.
    var hint = "0,00"
    /// Focused when the sheet opens, so typing can start at once.
    var autofocus = false
    /// An amount: while amounts are hidden it shows a bar until it is clicked into. A name or a note is not one.
    var secret = true
    @FocusState private var focused: Bool
    @Environment(\.redactionReasons) private var redaction
    /// Clicked or typed into: it shows what it holds, as typing over a bar can't be right. Focus alone isn't
    /// enough, as the Mac focuses a drawer's first field by itself.
    @State private var revealed = false

    private var hiding: Bool { secret && redaction.contains(.privacy) }
    private var masked: Bool { hiding && !revealed && !text.isEmpty }

    var body: some View {
        TextField("", text: $text)
            .font(large ? Kit.amount : Kit.body)
            .textFieldStyle(.plain)
            .multilineTextAlignment(align)
            .monospacedDigit()
            .foregroundStyle(masked ? Color.clear : valid ? Color.white : .red)
            // Drawn here, faint: a TextField's own prompt shows almost as bright as typed text.
            .overlay(alignment: align == .leading ? .leading : .trailing) {
                if masked {
                    // One bar the same width whatever the amount.
                    Text("0 000,00").font(large ? Kit.amount : Kit.body).monospacedDigit()
                        .redacted(reason: .placeholder).allowsHitTesting(false)
                } else if text.isEmpty {
                    Text(hint).font(large ? Kit.amount : Kit.body).monospacedDigit().opacity(0.22).allowsHitTesting(false)
                }
            }
            // Room scales with the type, so a big number never touches the field's ends.
            .padding(.horizontal, large ? 10 : 8)
            .padding(.vertical, large ? 4 : 3)
            .background(.white.opacity(focused ? 0.12 : 0.06),
                        in: RoundedRectangle(cornerRadius: large ? 10 : 8, style: .continuous))
            .focused($focused)
            .simultaneousGesture(TapGesture().onEnded { revealed = true })
            .onChange(of: text) { revealed = true }
            // Hidden, it waits to be clicked into rather than showing its amount as the sheet opens.
            .onAppear { focused = autofocus && !hiding }
            .accessibilityLabel(label)
    }
}

/// The amount at the top of a sheet: its label, the field and the euro sign, the same in every sheet.
struct AmountField: View {
    let label: String
    @Binding var text: String
    var valid = true
    var autofocus = false

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.label) {
            Text(label).eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                GlassField(label: label, text: $text, large: true, align: .leading, valid: valid, autofocus: autofocus)
                    .frame(width: Kit.largeField)
                Text("€").font(.system(size: 15, weight: .semibold)).opacity(0.5)
            }
        }
    }
}

/// Cancel on the left, the one action on the right, a little apart from what is above.
struct SheetFooter<Action: View>: View {
    let cancel: () -> Void
    @ViewBuilder let action: Action

    var body: some View {
        HStack {
            Button("Cancel", action: cancel).buttonStyle(.quiet).keyboardShortcut(.cancelAction)
            Spacer()
            action.keyboardShortcut(.defaultAction)
        }
        .padding(.top, Kit.Space.edge - Kit.Space.group)
    }
}

