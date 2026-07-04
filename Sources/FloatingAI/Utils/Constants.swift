import Foundation

/// App-wide constants and identifiers.
enum AppInfo {
    static let bundleIdentifier = "com.floatingai.assistant"
    static let displayName = "Floating AI"
    static let keychainService = "com.floatingai.assistant"
    static let keychainAccount = "openai_api_key"

    /// UserDefaults keys.
    enum Defaults {
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let settings = "appSettings"
        static let widgetPositionX = "widgetPositionX"
        static let widgetPositionY = "widgetPositionY"
    }
}
