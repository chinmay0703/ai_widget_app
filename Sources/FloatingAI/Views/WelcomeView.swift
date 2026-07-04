import SwiftUI

/// First-launch onboarding: welcome → API key → Accessibility → done.
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    var onFinish: () -> Void

    private enum Step { case welcome, apiKey, accessibility, done }

    @State private var step: Step = .welcome
    @State private var apiKey = ""
    @State private var validating = false
    @State private var validationError: String?
    @State private var trusted = AccessibilityService.isTrusted

    private let pollTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(width: 460, height: 540)
        .onReceive(pollTimer) { _ in
            if step == .accessibility { trusted = AccessibilityService.isTrusted }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .apiKey: apiKeyStep
        case .accessibility: accessibilityStep
        case .done: doneStep
        }
    }

    // MARK: - Steps

    private var logo: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 0.98),
                                              Color(red: 0.58, green: 0.30, blue: 0.92)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84)
            Text("AI").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()
            logo
            Text("Welcome to Floating AI").font(.title).bold()
            Text("An AI assistant that lives in your menu bar. Select text anywhere, then press ⌘⇧K to explain, rewrite, summarize, and more — using your own OpenAI API key.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect your OpenAI key").font(.title2).bold()
            Text("Your key is stored only on this Mac, in the macOS Keychain. It is sent directly to OpenAI and nowhere else.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("sk-…", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onSubmit(validateAndSave)

            if let validationError {
                Label(validationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Link("Where do I find my API key?",
                 destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.footnote)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grant Accessibility access").font(.title2).bold()
            Text("Floating AI needs Accessibility permission to read the text you select (via Copy) and to insert responses back (via Paste). You can revoke this anytime in System Settings.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: trusted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(trusted ? .green : .secondary)
                Text(trusted ? "Accessibility access granted" : "Not yet granted")
                    .foregroundStyle(trusted ? .green : .secondary)
            }
            .font(.callout)

            Button {
                AccessibilityService.ensureTrusted(prompt: true)
                AccessibilityService.openSystemSettings()
            } label: {
                Label("Open Accessibility Settings", systemImage: "hand.raised")
            }
            .disabled(trusted)

            Text("After enabling Floating AI in the list, return here.")
                .font(.footnote).foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.green)
            Text("You're all set!").font(.title).bold()
            Text("Select text in any app, then press ⌘⇧K to open the assistant. You'll also find Floating AI in your menu bar (the ✦ icon) for Settings and History.")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step != .welcome && step != .done {
                Button("Back") { back() }.buttonStyle(.link)
            }
            Spacer()
            primaryButton
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(.bar)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .welcome:
            Button("Get Started") { step = .apiKey }
                .keyboardShortcut(.defaultAction)
        case .apiKey:
            Button {
                validateAndSave()
            } label: {
                HStack(spacing: 6) {
                    if validating { ProgressView().controlSize(.small) }
                    Text(validating ? "Validating…" : "Validate & Save")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(validating || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
        case .accessibility:
            Button(trusted ? "Continue" : "Skip for now") { step = .done }
                .keyboardShortcut(.defaultAction)
        case .done:
            Button("Start Using Floating AI") { finish() }
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    private func back() {
        switch step {
        case .accessibility: step = .apiKey
        case .apiKey: step = .welcome
        default: break
        }
    }

    private func validateAndSave() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        validating = true
        validationError = nil
        Task {
            let result = await OpenAIService(apiKey: key).validateKey()
            validating = false
            switch result {
            case .success:
                appState.setAPIKey(key)
                trusted = AccessibilityService.isTrusted
                step = .accessibility
            case .failure(let error):
                validationError = error.errorDescription
            }
        }
    }

    private func finish() {
        appState.completeOnboarding()
        onFinish()
    }
}
