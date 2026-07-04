import Foundation

/// App-internal notifications used to decouple SwiftUI views from the AppKit
/// window controllers that own the panels.
extension Notification.Name {
    static let triggerAssistant = Notification.Name("FloatingAI.triggerAssistant")
    static let openSettings = Notification.Name("FloatingAI.openSettings")
    static let openHistory = Notification.Name("FloatingAI.openHistory")
    static let selectHistoryTab = Notification.Name("FloatingAI.selectHistoryTab")
    static let hotkeyPreferenceChanged = Notification.Name("FloatingAI.hotkeyPreferenceChanged")
    static let onboardingFinished = Notification.Name("FloatingAI.onboardingFinished")
    static let quitApp = Notification.Name("FloatingAI.quitApp")
}
