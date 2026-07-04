import SwiftUI

/// The assistant popup: selected text, quick actions, prompt box, the running
/// conversation, and the Copy / Replace / Insert output actions.
///
/// The scrollable middle sizes itself to its content (up to a cap) so the whole
/// window stays compact, then scrolls once the conversation grows.
struct PopupView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @EnvironmentObject var appState: AppState
    var onClose: () -> Void

    @FocusState private var promptFocused: Bool
    @State private var didCopy = false

    // Fixed size — a dynamically-sized popup created a runaway
    // update-constraints loop in AppKit that crashed the app.
    private let popupWidth: CGFloat = 380
    private let popupHeight: CGFloat = 520

    private var hasConversation: Bool { !viewModel.messages.isEmpty }

    /// Cap the displayed selection so a huge selection doesn't stall layout.
    private let displayCap = 1200
    private var displayedSelection: String {
        let t = viewModel.selectedText
        return t.count > displayCap ? String(t.prefix(displayCap)) + "…" : t
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.hasSelection {
                            selectedTextSection
                        }
                        if !hasConversation {
                            quickActions
                        } else {
                            conversation
                        }
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(12)
                }
                .frame(maxHeight: .infinity)
                .onChange(of: viewModel.messages) { _ in
                    // Fires on every streamed token; no animation (janky/expensive).
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            Divider()
            if !viewModel.latestResponse.isEmpty {
                outputActionBar
                Divider()
            }
            promptBar
        }
        .frame(width: popupWidth, height: popupHeight)
        .background(.thinMaterial)
        .onAppear { promptFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
            Text(hasConversation ? viewModel.actionTitle : "AI Assistant")
                .font(.headline)
            Spacer()
            modelPicker
            Button {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var modelPicker: some View {
        Picker("Model", selection: modelBinding) {
            ForEach(modelOptions, id: \.id) { option in
                Text(option.label).tag(option.id)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: 140)
        .help("Model")
    }

    private var modelOptions: [OpenAIModelOption] {
        var options = OpenAIModelCatalog.defaults
        let current = appState.settings.model
        if !options.contains(where: { $0.id == current }) {
            options.insert(OpenAIModelOption(current, current), at: 0)
        }
        return options
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { appState.settings.model },
            set: { newValue in appState.updateSettings { $0.model = newValue } }
        )
    }

    // MARK: - Selected text

    private var selectedTextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Selected Text", systemImage: "text.quote")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if viewModel.selectedText.count > displayCap {
                    Text("\(viewModel.selectedText.count) chars")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            // Only the display is truncated; the full selection is still sent
            // to the model. Rendering very long strings in a Text view is slow.
            Text(displayedSelection)
                .font(.callout)
                .lineLimit(4)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Actions")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(PromptTemplate.library) { template in
                    Button {
                        if !template.defaultPrompt.isEmpty && viewModel.promptText.isEmpty {
                            viewModel.promptText = template.defaultPrompt
                        }
                        viewModel.run(template: template)
                    } label: {
                        Label(template.title, systemImage: template.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canRunAction)
                }
            }
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.messages) { message in
                MessageBubble(message: message)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Output actions

    private var outputActionBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.copyResponse()
                flashCopied()
            } label: {
                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
            }
            Button {
                viewModel.replaceSelection()
                onClose()
            } label: {
                Label("Replace", systemImage: "arrow.left.arrow.right")
            }
            .disabled(!viewModel.hasSelection)
            .help(viewModel.hasSelection ? "Replace the selected text" : "No selection to replace")

            Button {
                viewModel.insertResponse()
                onClose()
            } label: {
                Label("Insert", systemImage: "text.insert")
            }
            Spacer()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func flashCopied() {
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { didCopy = false }
    }

    // MARK: - Prompt bar

    private var promptBar: some View {
        HStack(spacing: 8) {
            TextField(hasConversation ? "Ask a follow-up…" : "Ask anything…",
                      text: $viewModel.promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($promptFocused)
                .onSubmit(submit)
                .padding(8)
                .background(Color.secondary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if viewModel.isLoading {
                Button(action: viewModel.cancel) {
                    Image(systemName: "stop.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Stop")
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(!canSubmit)
                .help("Send (↩)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var canSubmit: Bool {
        !viewModel.isLoading &&
        (!viewModel.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         || (!hasConversation && viewModel.hasSelection))
    }

    private func submit() {
        guard canSubmit else { return }
        if hasConversation {
            viewModel.sendFollowUp()
        } else {
            viewModel.run(template: nil)
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 32) }
            content
            if message.role == .assistant { Spacer(minLength: 32) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.role {
        case .user:
            Text(message.text)
                .textSelection(.enabled)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

        case .assistant:
            Group {
                if message.text.isEmpty && message.isStreaming {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Thinking…").foregroundStyle(.secondary)
                    }
                } else {
                    MarkdownView(text: message.text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        case .system:
            EmptyView()
        }
    }
}
