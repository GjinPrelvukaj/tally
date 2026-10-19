import SwiftUI

/// "Ask about your money" at the top of Insights: the question is read on this Mac (`AskReader`), the answer is
/// written by code from the ledger (`Ledger.answer`), so it follows the data as it changes. Under it, how the
/// question was understood, so a misreading shows.
struct AskBox: View {
    let store: Store
    let today: Date
    @Environment(\.partnerName) private var partnerName
    @State private var text = ""
    @State private var question: Question?
    @State private var asking = false
    @State private var unread = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            field
            if let question {
                answer(store.ledger().answer(question, today: today, partnerName: partnerName))
            } else if unread {
                Text("Tally couldn't read that one. Try “coffee this month” or “what can I spend a day”.")
                    .font(Kit.quiet).opacity(0.5)
            }
            if question == nil && !asking { examples }
        }
        .padding(.bottom, Kit.Space.item)
    }

    private var field: some View {
        HStack(spacing: Kit.Space.item) {
            Image(systemName: "sparkles").font(Kit.body).opacity(focused ? 0.85 : 0.5)
            TextField("", text: $text)
                .font(Kit.body)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { ask(text) }
                .overlay(alignment: .leading) {
                    if text.isEmpty { Text("Ask about your money").font(Kit.body).opacity(0.3).allowsHitTesting(false) }
                }
            if asking { ProgressView().controlSize(.small) }
            else if question != nil { Button("Clear", action: clear).buttonStyle(.quiet) }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.white.opacity(focused ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(focused ? 0.14 : 0.07), lineWidth: 1))
        .accessibilityLabel("Ask about your money")
    }

    private var examples: some View {
        let asks = ["Where did my money go this week?", "Can I spend more today?"] + (partnerName.isEmpty ? [] : ["What does \(partnerName) owe me?"])
        return HStack(spacing: Kit.Space.item) {
            ForEach(asks, id: \.self) { example in
                Button(example) { text = example; ask(example) }.buttonStyle(.chip())
            }
        }
    }

    private func answer(_ answer: Answer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(answer.understood).font(Living.caption).opacity(0.45)
            Text(answer.title).font(Kit.body.weight(.medium)).privacySensitive()
            ForEach(answer.lines, id: \.self) { Text($0).font(Kit.quiet).opacity(0.6).privacySensitive() }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowPanel()
        .accessibilityElement(children: .combine)
    }

    private func ask(_ words: String) {
        let words = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty, !asking else { return }
        asking = true
        unread = false
        Task {
            let read = await AskReader.read(words, categories: store.ledger().categories, partnerName: partnerName)
            asking = false
            question = read
            unread = read == nil
        }
    }

    private func clear() {
        text = ""
        question = nil
        unread = false
        focused = true
    }
}
