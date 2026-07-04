import Foundation

/// A saved interaction, shown in the History view.
struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    /// The quick-action title or "Custom".
    let action: String
    let model: String
    let selectedText: String
    let prompt: String
    let response: String

    init(id: UUID = UUID(),
         date: Date,
         action: String,
         model: String,
         selectedText: String,
         prompt: String,
         response: String) {
        self.id = id
        self.date = date
        self.action = action
        self.model = model
        self.selectedText = selectedText
        self.prompt = prompt
        self.response = response
    }

    var title: String {
        let base = prompt.isEmpty ? action : prompt
        return base.replacingOccurrences(of: "\n", with: " ")
    }
}
