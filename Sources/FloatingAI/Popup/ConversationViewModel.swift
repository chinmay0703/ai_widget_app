import AppKit
import Combine

/// Drives a single popup session: the selected text, the running conversation,
/// streaming state, and the Copy / Replace / Insert actions.
@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var promptText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var actionTitle: String = "Custom"

    let selectedText: String
    /// The app that was frontmost when capture happened — the paste target.
    private let previousApp: NSRunningApplication?
    private unowned let appState: AppState

    private var instructions: String = ""
    private var streamTask: Task<Void, Never>?
    private var didSaveHistory = false
    private var firstPrompt: String = ""

    init(selectedText: String, previousApp: NSRunningApplication?, appState: AppState) {
        self.selectedText = selectedText
        self.previousApp = previousApp
        self.appState = appState
    }

    var hasSelection: Bool { !selectedText.isEmpty }

    var latestResponse: String {
        messages.last(where: { $0.role == .assistant && !$0.text.isEmpty })?.text ?? ""
    }

    var canRunAction: Bool { !isLoading }

    // MARK: - Running actions

    /// Run a quick-action template (Explain, Summarize, …) or a custom prompt.
    func run(template: PromptTemplate?) {
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        if template == nil && prompt.isEmpty && !hasSelection { return }

        actionTitle = template?.title ?? "Custom"
        instructions = template?.instructions ?? ""
        firstPrompt = prompt

        let displayText = prompt.isEmpty ? (template?.title ?? "…") : prompt
        messages.append(ChatMessage(role: .user, text: displayText))
        promptText = ""
        startStream()
    }

    /// Continue the conversation with a follow-up message.
    func sendFollowUp() {
        let text = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        messages.append(ChatMessage(role: .user, text: text))
        promptText = ""
        startStream()
    }

    private func startStream() {
        guard let service = appState.makeService() else {
            errorMessage = AppError.missingAPIKey.errorDescription
            return
        }

        errorMessage = nil
        isLoading = true

        let payload = apiMessages()
        let system = combinedSystemPrompt()
        let model = appState.settings.model
        let temperature = appState.settings.temperature
        let useStreaming = appState.settings.streamResponses

        // Append the assistant placeholder that we stream into.
        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        let index = messages.count - 1

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                if useStreaming {
                    let stream = service.streamResponse(messages: payload,
                                                        instructions: system,
                                                        model: model,
                                                        temperature: temperature)
                    for try await chunk in stream {
                        guard index < self.messages.count else { break }
                        self.messages[index].text += chunk
                    }
                } else {
                    let text = try await service.respond(messages: payload,
                                                         instructions: system,
                                                         model: model,
                                                         temperature: temperature)
                    if index < self.messages.count { self.messages[index].text = text }
                }
                self.finishStream(at: index, error: nil)
            } catch {
                self.finishStream(at: index, error: error)
            }
        }
    }

    private func finishStream(at index: Int, error: Error?) {
        isLoading = false
        if index < messages.count {
            messages[index].isStreaming = false
        }

        if let error {
            // Drop an empty placeholder so we don't leave a blank bubble.
            if index < messages.count && messages[index].text.isEmpty {
                messages.remove(at: index)
            }
            if let appError = error as? AppError, appError == .cancelled { return }
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            return
        }

        saveHistoryIfNeeded()
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
    }

    // MARK: - Output actions

    func copyResponse() {
        ClipboardService.copyToClipboard(latestResponse)
    }

    /// Replace the original selection with the response (paste over selection).
    func replaceSelection() {
        pasteResponse()
    }

    /// Insert the response at the cursor in the original app.
    func insertResponse() {
        pasteResponse()
    }

    private func pasteResponse() {
        let text = latestResponse
        guard !text.isEmpty else { return }
        let restore = appState.settings.restoreClipboardAfterCapture
        let app = previousApp
        Task {
            await ClipboardService.paste(text: text, into: app, restoreClipboard: restore)
        }
    }

    // MARK: - Payload assembly

    /// Builds the messages sent to the API, folding the selected text into the
    /// first user turn so the model has the context without cluttering the UI.
    private func apiMessages() -> [ChatMessage] {
        var result = messages
        if hasSelection,
           let firstUserIndex = result.firstIndex(where: { $0.role == .user }) {
            var first = result[firstUserIndex]
            first.text = Self.compose(prompt: firstPrompt, selectedText: selectedText)
            result[firstUserIndex] = first
        }
        return result
    }

    private func combinedSystemPrompt() -> String {
        [appState.settings.systemPrompt, instructions]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func compose(prompt: String, selectedText: String) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.isEmpty {
            return "Here is the text to work with:\n\n\"\"\"\n\(selectedText)\n\"\"\""
        }
        return "\(trimmedPrompt)\n\nText:\n\"\"\"\n\(selectedText)\n\"\"\""
    }

    private func saveHistoryIfNeeded() {
        guard !didSaveHistory, !latestResponse.isEmpty else { return }
        didSaveHistory = true
        let item = HistoryItem(
            date: Date(),
            action: actionTitle,
            model: appState.settings.model,
            selectedText: selectedText,
            prompt: firstPrompt,
            response: latestResponse
        )
        appState.history.add(item)
    }
}
