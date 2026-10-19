import Foundation
import FoundationModels

/// Reads a question about the money into a `Question`, with Apple's on-device model (`SystemLanguageModel`, on
/// this Mac; never the cloud one). It only fills in the shape: the answer is written by `Ledger.answer`, and the
/// reading is checked against the question's own words (`Question.checked`) before it is used.
enum AskReader {
    /// On a Mac with Apple Intelligence on; otherwise there is no question box.
    static var available: Bool { SystemLanguageModel.default.isAvailable }

    @Generable enum Topic { case spending, search, balances, allowance, partner, insights }
    @Generable enum Period { case today, thisWeek, lastWeek, thisMonth, lastMonth }

    @Generable struct Reading {
        @Guide(description: "spending: how much was spent, maybe in one category. search: spends on a named thing (coffee, cigarettes, Netflix). balances: what is in the pots or accounts now, what the card owes. allowance: how much can be spent a day, what is left until payday, what is still to pay. partner: the partner, what they owe, time together. insights: what is wrong, what to watch, how am I doing.")
        var topic: Topic
        @Guide(description: "The period asked about. thisMonth when none is said.")
        var period: Period
        @Guide(description: "Exactly one of the person's category names when the question is about that category, otherwise empty.")
        var category: String
        @Guide(description: "For search: the thing to look for, one or two lowercase words as written (coffee, cigarettes). Otherwise empty.")
        var search: String
    }

    /// Nil when the model couldn't read it.
    static func read(_ text: String, categories: [Category], partnerName: String) async -> Question? {
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: """
            You read a question someone asks about their own money and fill in its fields. Don't answer it.
            Their categories are: \(categories.filter { !$0.retired }.map(\.name).joined(separator: ", ")).\
            \(partnerName.isEmpty ? "" : " Their partner is \(partnerName).")
            """)
        guard let reading = try? await session.respond(to: text, generating: Reading.self,
                                                        options: GenerationOptions(temperature: 0)).content else { return nil }
        let topic: Question.Topic = switch reading.topic {
        case .spending: .spending
        case .search: .search
        case .balances: .balances
        case .allowance: .allowance
        case .partner: .partner
        case .insights: .insights
        }
        let period: Question.Period = switch reading.period {
        case .today: .today
        case .thisWeek: .thisWeek
        case .lastWeek: .lastWeek
        case .thisMonth: .thisMonth
        case .lastMonth: .lastMonth
        }
        return Question(topic: topic, period: period, category: reading.category.isEmpty ? nil : reading.category,
                        search: reading.search.isEmpty ? nil : reading.search)
            .checked(against: text, categories: categories, partnerName: partnerName)
    }
}
