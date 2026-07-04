import AppKit
import CoreGraphics

/// Reads the current selection (via synthetic Cmd+C) and writes text back
/// (via synthetic Cmd+V), snapshotting and restoring the user's clipboard.
///
/// All keystroke injection requires Accessibility permission.
enum ClipboardService {
    private static let keyC: CGKeyCode = 0x08   // kVK_ANSI_C
    private static let keyV: CGKeyCode = 0x09   // kVK_ANSI_V

    // MARK: - Capture

    /// Copy the current selection from the frontmost app and return it.
    /// Returns nil if nothing was selected (clipboard did not change).
    static func captureSelectedText(restoreClipboard: Bool) async -> String? {
        guard AccessibilityService.isTrusted else {
            Log.clipboard.error("captureSelectedText called without Accessibility trust")
            return nil
        }

        let pb = NSPasteboard.general
        let snapshot = restoreClipboard ? self.snapshot(pb) : nil
        let startCount = pb.changeCount

        simulateModifierKey(keyC)

        // Poll for the pasteboard to update (apps respond asynchronously).
        var captured: String?
        for _ in 0..<25 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            if pb.changeCount != startCount {
                captured = pb.string(forType: .string)
                break
            }
        }

        if let snapshot {
            restore(pb, items: snapshot)
        }

        let trimmed = captured?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? captured : nil
    }

    // MARK: - Insert / Replace

    /// Put `text` on the clipboard, bring `targetApp` forward, and paste it.
    /// Used by both Insert (at cursor) and Replace (over the selection).
    static func paste(text: String,
                      into targetApp: NSRunningApplication?,
                      restoreClipboard: Bool) async {
        guard AccessibilityService.isTrusted else {
            Log.clipboard.error("paste called without Accessibility trust")
            return
        }

        let pb = NSPasteboard.general
        let snapshot = restoreClipboard ? self.snapshot(pb) : nil

        pb.clearContents()
        pb.setString(text, forType: .string)

        if let targetApp {
            targetApp.activate(options: [])
            // Give the target a moment to become frontmost before pasting.
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
        }

        simulateModifierKey(keyV)

        if let snapshot {
            // Restore only after the paste has been consumed by the target app.
            try? await Task.sleep(nanoseconds: 250_000_000) // 250ms
            restore(pb, items: snapshot)
        }
    }

    /// Copy text to the clipboard without pasting (the "Copy" action).
    static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Keystroke injection

    private static func simulateModifierKey(_ key: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard snapshot / restore

    private static func snapshot(_ pb: NSPasteboard) -> [NSPasteboardItem] {
        var copies: [NSPasteboardItem] = []
        for item in pb.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            copies.append(copy)
        }
        return copies
    }

    private static func restore(_ pb: NSPasteboard, items: [NSPasteboardItem]) {
        pb.clearContents()
        if !items.isEmpty {
            pb.writeObjects(items)
        }
    }
}
