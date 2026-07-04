import Foundation

/// A reusable quick action that turns selected text into a model request.
struct PromptTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    /// SF Symbol name for the button.
    let systemImage: String
    /// System instructions sent to the model for this action.
    let instructions: String
    /// Optional user-visible prompt prefilled into the prompt box (e.g. Translate).
    let defaultPrompt: String

    init(id: String, title: String, systemImage: String, instructions: String, defaultPrompt: String = "") {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.instructions = instructions
        self.defaultPrompt = defaultPrompt
    }
}

extension PromptTemplate {
    /// The built-in prompt library described in the design doc.
    static let library: [PromptTemplate] = [
        PromptTemplate(
            id: "explain",
            title: "Explain",
            systemImage: "lightbulb",
            instructions: "You are a clear, concise explainer. Explain the user's selected text in plain language. Use short paragraphs and, where helpful, bullet points."
        ),
        PromptTemplate(
            id: "summarize",
            title: "Summarize",
            systemImage: "text.append",
            instructions: "Summarize the user's selected text. Capture the key points faithfully in as few words as possible. Prefer a tight bulleted list when there are multiple points."
        ),
        PromptTemplate(
            id: "rewrite",
            title: "Rewrite",
            systemImage: "arrow.triangle.2.circlepath",
            instructions: "Rewrite the user's selected text to be clearer and more fluent while preserving its meaning and tone. Return only the rewritten text with no preamble."
        ),
        PromptTemplate(
            id: "grammar",
            title: "Fix Grammar",
            systemImage: "checkmark.seal",
            instructions: "Correct spelling, grammar, and punctuation in the user's selected text. Preserve the original meaning, voice, and formatting. Return only the corrected text with no commentary."
        ),
        PromptTemplate(
            id: "translate",
            title: "Translate",
            systemImage: "globe",
            instructions: "Translate the user's selected text into the target language they specify. If no language is specified, translate to English. Return only the translation.",
            defaultPrompt: "Translate to English"
        ),
        PromptTemplate(
            id: "tone",
            title: "Improve Tone",
            systemImage: "wand.and.stars",
            instructions: "Rewrite the user's selected text to sound more polished, professional, and friendly, without changing its meaning. Return only the revised text."
        )
    ]
}
