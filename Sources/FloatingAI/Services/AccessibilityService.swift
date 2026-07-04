import AppKit
import ApplicationServices

/// Wraps the AXIsProcessTrusted APIs used to gate clipboard/keystroke injection.
enum AccessibilityService {
    /// True if the app currently has Accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Check trust and, if requested, prompt the user (opens System Settings).
    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open the Accessibility pane in System Settings directly.
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
