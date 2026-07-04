import SwiftUI

/// The Settings window: General, History, and About tabs.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private enum Tab: Hashable { case general, history, about }
    @State private var selection: Tab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(Tab.history)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .frame(width: 520, height: 560)
        .onReceive(NotificationCenter.default.publisher(for: .selectHistoryTab)) { _ in
            selection = .history
        }
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject var appState: AppState

    @State private var newKey = ""
    @State private var keyMessage: String?
    @State private var trusted = AccessibilityService.isTrusted

    var body: some View {
        Form {
            Section("OpenAI API Key") {
                HStack {
                    Image(systemName: appState.hasAPIKey ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(appState.hasAPIKey ? .green : .secondary)
                    Text(appState.hasAPIKey ? "A key is stored in your Keychain." : "No key stored.")
                        .foregroundStyle(.secondary)
                }
                SecureField("Enter a new key (sk-…)", text: $newKey)
                HStack {
                    Button("Save Key") {
                        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !key.isEmpty else { return }
                        appState.setAPIKey(key)
                        newKey = ""
                        keyMessage = "Saved."
                    }
                    .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Remove Key", role: .destructive) {
                        appState.removeAPIKey()
                        keyMessage = "Removed."
                    }
                    .disabled(!appState.hasAPIKey)

                    if let keyMessage {
                        Text(keyMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Model") {
                Picker("Model", selection: binding(\.model)) {
                    ForEach(modelOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                TextField("Custom model id", text: binding(\.model))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Behavior") {
                VStack(alignment: .leading) {
                    Text("System prompt").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: binding(\.systemPrompt))
                        .font(.callout)
                        .frame(height: 70)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                }
                HStack {
                    Text("Temperature")
                    Slider(value: binding(\.temperature), in: 0...2, step: 0.1)
                    Text(String(format: "%.1f", appState.settings.temperature))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Toggle("Enable ⌘⇧K global shortcut", isOn: hotkeyBinding)
                Toggle("Stream responses", isOn: binding(\.streamResponses))
                Toggle("Restore clipboard after capture", isOn: binding(\.restoreClipboardAfterCapture))
            }

            Section("Accessibility") {
                HStack {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Accessibility access granted." : "Accessibility access is required to capture text.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Recheck") { trusted = AccessibilityService.isTrusted; appState.refreshAccessibility() }
                }
                if !trusted {
                    Button("Open Accessibility Settings") {
                        AccessibilityService.ensureTrusted(prompt: true)
                        AccessibilityService.openSystemSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { trusted = AccessibilityService.isTrusted }
    }

    private var modelOptions: [OpenAIModelOption] {
        var options = OpenAIModelCatalog.defaults
        let current = appState.settings.model
        if !options.contains(where: { $0.id == current }) {
            options.insert(OpenAIModelOption(current, current), at: 0)
        }
        return options
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { appState.settings[keyPath: keyPath] },
            set: { newValue in appState.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var hotkeyBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.hotkeyEnabled },
            set: { newValue in
                appState.updateSettings { $0.hotkeyEnabled = newValue }
                NotificationCenter.default.post(name: .hotkeyPreferenceChanged, object: nil)
            }
        )
    }
}

// MARK: - About

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.42, blue: 0.98),
                                                  Color(red: 0.58, green: 0.30, blue: 0.92)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                Text("AI").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            Text(AppInfo.displayName).font(.title2).bold()
            Text("Version \(appVersion)")
                .font(.callout).foregroundStyle(.secondary)
            Text("A native macOS floating assistant powered by the OpenAI Responses API. Your API key stays on this Mac.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            Spacer()
            Button("Quit Floating AI") {
                NotificationCenter.default.post(name: .quitApp, object: nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
