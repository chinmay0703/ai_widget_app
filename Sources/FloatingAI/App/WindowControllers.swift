import AppKit
import SwiftUI

/// Hosts the first-launch onboarding flow in a centered window.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let appState: AppState
    private let onFinish: () -> Void

    init(appState: AppState, onFinish: @escaping () -> Void) {
        self.appState = appState
        self.onFinish = onFinish
        super.init()
    }

    func show() {
        if window == nil {
            let root = WelcomeView(onFinish: { [weak self] in self?.handleFinish() })
                .environmentObject(appState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            // NSHostingController (not a raw NSHostingView contentView) avoids the
            // AppKit constraint-update crash on safe-area/display changes.
            window.contentViewController = NSHostingController(rootView: root)
            window.center()
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.orderOut(nil) }

    private func handleFinish() {
        window?.orderOut(nil)
        onFinish()
    }
}

/// Hosts the "Enable Accessibility" prompt window.
@MainActor
final class AccessibilityController: NSObject {
    private var window: NSWindow?
    private let onRelaunch: () -> Void

    init(onRelaunch: @escaping () -> Void) {
        self.onRelaunch = onRelaunch
        super.init()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            let root = AccessibilityView(
                onOpenSettings: {
                    AccessibilityService.ensureTrusted(prompt: true)
                    AccessibilityService.openSystemSettings()
                },
                onRelaunch: { [weak self] in self?.onRelaunch() },
                onClose: { [weak self] in self?.close() }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.contentViewController = NSHostingController(rootView: root)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }
}

/// Hosts the Settings window (reused across opens).
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func show() {
        if window == nil {
            let root = SettingsView().environmentObject(appState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Floating AI Settings"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: root)
            window.center()
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.orderOut(nil) }
}
