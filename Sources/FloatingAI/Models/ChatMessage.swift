import Foundation

/// A single turn in a conversation with the model.
struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    let id: UUID
    var role: Role
    var text: String
    /// True while the assistant reply is still streaming in.
    var isStreaming: Bool

    init(id: UUID = UUID(), role: Role, text: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
    }
}
