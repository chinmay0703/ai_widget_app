import AppKit
import Combine

/// Shared, observable app state injected into every window's SwiftUI tree.
@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published private(set) var hasAPIKey: Bool
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var didCompleteOnboarding: Bool

    let history: HistoryStore

    init(history: HistoryStore) {
        self.history = history
        self.settings = AppSettings.load()
        self.hasAPIKey = KeychainService.hasAPIKey
        self.isAccessibilityTrusted = AccessibilityService.isTrusted
        self.didCompleteOnboarding = UserDefaults.standard.bool(forKey: AppInfo.Defaults.didCompleteOnboarding)
    }

    // MARK: - Settings

    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        var copy = settings
        transform(&copy)
        settings = copy
        copy.save()
    }

    // MARK: - API key

    @discardableResult
    func setAPIKey(_ key: String) -> Bool {
        let ok = KeychainService.save(apiKey: key)
        hasAPIKey = KeychainService.hasAPIKey
        return ok
    }

    func removeAPIKey() {
        KeychainService.deleteAPIKey()
        hasAPIKey = KeychainService.hasAPIKey
    }

    func makeService() -> OpenAIService? {
        guard let key = KeychainService.loadAPIKey(), !key.isEmpty else { return nil }
        return OpenAIService(apiKey: key)
    }

    // MARK: - Permissions / onboarding

    func refreshAccessibility() {
        isAccessibilityTrusted = AccessibilityService.isTrusted
    }

    func completeOnboarding() {
        didCompleteOnboarding = true
        UserDefaults.standard.set(true, forKey: AppInfo.Defaults.didCompleteOnboarding)
    }

    /// True once the app is ready to show its floating widget.
    var isReady: Bool {
        didCompleteOnboarding && hasAPIKey
    }
}
