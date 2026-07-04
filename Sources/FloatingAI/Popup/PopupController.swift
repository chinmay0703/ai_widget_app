import AppKit
import SwiftUI

/// Presents the assistant popup near the cursor and tears it down cleanly.
///
/// The popup auto-sizes to its SwiftUI content (via `NSHostingController`),
/// re-anchors as it grows, and dismisses itself when it loses key focus
/// (i.e. the user clicks outside it).
@MainActor
final class PopupController: NSObject, NSWindowDelegate {
    private var panel: PopupPanel?
    private var viewModel: ConversationViewModel?
    private let appState: AppState
    private let size = NSSize(width: 380, height: 520)
    /// Where the popup anchors — the cursor location at trigger time.
    private var anchorPoint: NSPoint = .zero
    /// Suppresses the resign-key auto-close while we intentionally tear down.
    private var isClosing = false

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Show the popup for a freshly captured selection, near the cursor.
    func present(selectedText: String,
                 previousApp: NSRunningApplication?) {
        close()
        isClosing = false
        anchorPoint = NSEvent.mouseLocation

        let vm = ConversationViewModel(selectedText: selectedText,
                                       previousApp: previousApp,
                                       appState: appState)
        viewModel = vm

        let root = PopupView(viewModel: vm, onClose: { [weak self] in self?.close() })
            .environmentObject(appState)

        let panel = PopupPanel(contentRect: NSRect(origin: .zero, size: size))
        // Fixed size + NO sizingOptions: dynamic sizing caused a runaway
        // update-constraints-in-window loop that crashed AppKit.
        let hostingController = NSHostingController(rootView: root)
        panel.contentViewController = hostingController
        panel.setContentSize(size)
        panel.delegate = self
        self.panel = panel

        reanchor()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        isClosing = true
        viewModel?.cancel()
        if let panel {
            panel.delegate = nil
            panel.orderOut(nil)
        }
        panel = nil
        viewModel = nil
    }

    // MARK: - Positioning

    /// Place the popup just below-right of the cursor, clamped fully on-screen.
    private func reanchor() {
        guard let panel else { return }
        let visible = (screen(containing: anchorPoint) ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Cursor sits at the popup's top-left; it drops down and to the right.
        var x = anchorPoint.x + 8
        var y = anchorPoint.y - size.height - 8

        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - size.height - 8)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    // MARK: - NSWindowDelegate

    /// Clicking anywhere outside the popup makes it resign key → dismiss.
    func windowDidResignKey(_ notification: Notification) {
        guard !isClosing else { return }
        close()
    }

    func windowWillClose(_ notification: Notification) {
        // Reached when AppKit closes the panel directly (e.g. Esc → performClose)
        // instead of via close(). Match close()'s invariants so a trailing
        // resign-key callback can't re-enter.
        isClosing = true
        viewModel?.cancel()
        if let window = notification.object as? NSWindow {
            window.delegate = nil
        }
        viewModel = nil
        panel = nil
    }
}
