import Foundation

/// A selectable OpenAI model.
struct OpenAIModelOption: Identifiable, Hashable {
    let id: String   // API model identifier
    let label: String

    init(_ id: String, _ label: String) {
        self.id = id
        self.label = label
    }
}

enum OpenAIModelCatalog {
    /// A small curated default list. Users can also type a custom model id in Settings.
    static let defaults: [OpenAIModelOption] = [
        OpenAIModelOption("gpt-4o-mini", "GPT-4o mini (fast, cheap)"),
        OpenAIModelOption("gpt-4o", "GPT-4o"),
        OpenAIModelOption("gpt-4.1-mini", "GPT-4.1 mini"),
        OpenAIModelOption("gpt-4.1", "GPT-4.1"),
        OpenAIModelOption("o4-mini", "o4-mini (reasoning)")
    ]

    static let fallbackModelID = "gpt-4o-mini"
}
