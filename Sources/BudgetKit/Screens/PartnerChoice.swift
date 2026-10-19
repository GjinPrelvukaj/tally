import SwiftUI

extension EnvironmentValues {
    /// The partner's name, from Settings (or the demo's own); empty, nothing of the partner shows.
    @Entry var partnerName = ""
}

/// How the partner was part of a spend: not at all, together, half theirs or all theirs; and, when part of it was
/// theirs, whether they pay it back.
struct PartnerChoice: View {
    let name: String
    @Binding var share: PartnerShare?
    @Binding var paysBack: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            // One glass bar where it fits (Quick log), chips two by two where it doesn't (the editor beside a list).
            ViewThatFits(in: .horizontal) {
                GlassSegments(selection: $share, choices: [(nil, "Just Me", "person"), (.with, "With \(name)", "person.2"),
                                                           (.half, "Half", "circle.lefthalf.filled"), (.forThem, "For \(name)", "gift")])
                Grid(horizontalSpacing: Kit.Space.item, verticalSpacing: Kit.Space.item) {
                    GridRow { choice("Just Me", nil); choice("With \(name)", .with) }
                    GridRow { choice("Half", .half); choice("For \(name)", .forThem) }
                }
            }
            if share == .half || share == .forThem {
                Toggle("\(name) Pays Me Back", isOn: $paysBack).toggleStyle(.glass)
                    .transition(.opacity)
            }
        }
    }

    private func choice(_ title: String, _ value: PartnerShare?) -> some View {
        Button { share = value } label: { Text(title).lineLimit(1).fixedSize().frame(maxWidth: .infinity) }
            .buttonStyle(.chip(chosen: share == value))
            .accessibilityAddTraits(share == value ? .isSelected : [])
    }
}
