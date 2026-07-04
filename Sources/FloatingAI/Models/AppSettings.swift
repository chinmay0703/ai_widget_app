import Foundation

/// User-configurable settings, persisted to UserDefaults as JSON.
struct AppSettings: Codable, Equatable {
    var model: String
    var systemPrompt: String
    var temperature: Double
    var hotkeyEnabled: Bool
    var streamResponses: Bool
    var restoreClipboardAfterCapture: Bool

    static let `default` = AppSettings(
        model: OpenAIModelCatalog.fallbackModelID,
        systemPrompt: "You are a helpful assistant embedded in a floating macOS widget. Be concise and directly useful.",
        temperature: 0.7,
        hotkeyEnabled: true,
        streamResponses: true,
        restoreClipboardAfterCapture: true
    )

    /// Load persisted settings, falling back to defaults on any error.
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: AppInfo.Defaults.settings),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AppInfo.Defaults.settings)
        }
    }
}
