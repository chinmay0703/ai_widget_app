import AppKit

/// Wires the app together: state, windows, the global hotkey, and the
/// select-text → capture → popup trigger flow.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let historyStore = HistoryStore()
    private lazy var appState = AppState(history: historyStore)

    private var statusItem: NSStatusItem?
    private lazy var popupController = PopupController(appState: appState)
    private lazy var settingsController = SettingsController(appState: appState)
    private lazy var onboardingController = OnboardingController(appState: appState, onFinish: { [weak self] in
        self?.finishOnboarding()
    })
    private lazy var accessibilityController = AccessibilityController(onRelaunch: { [weak self] in
        self?.relaunchApp()
    })
    private let hotKeyManager = HotKeyManager()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        appState.refreshAccessibility()
        registerObservers()
        configureHotKey()

        if appState.isReady {
            setupStatusItem()
        } else {
            onboardingController.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running as an accessory app even when auxiliary windows close.
        false
    }

    // MARK: - Trigger flow

    func trigger() {
        guard appState.isReady else {
            onboardingController.show()
            return
        }

        guard AccessibilityService.isTrusted else {
            appState.refreshAccessibility()
            // Show the guided prompt once (with a Restart button) instead of
            // re-triggering the system dialog on every click.
            accessibilityController.show()
            return
        }

        let previousApp = frontmostAppExcludingSelf()
        let restore = appState.settings.restoreClipboardAfterCapture

        Task {
            let text = await ClipboardService.captureSelectedText(restoreClipboard: restore)
            popupController.present(selectedText: text ?? "", previousApp: previousApp)
        }
    }

    private func frontmostAppExcludingSelf() -> NSRunningApplication? {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == Bundle.main.bundleIdentifier { return nil }
        return front
    }

    private func finishOnboarding() {
        configureHotKey()
        setupStatusItem()
    }

    // MARK: - Menu bar item

    private func setupStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: AppInfo.displayName)
            image?.isTemplate = true
            button.image = image
            button.toolTip = "\(AppInfo.displayName) — ⌘⇧K"
        }
        item.menu = buildStatusMenu()
        statusItem = item
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Assistant", action: #selector(menuOpenAssistant), keyEquivalent: "k")
        open.keyEquivalentModifierMask = [.command, .shift]
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let history = NSMenuItem(title: "History…", action: #selector(menuOpenHistory), keyEquivalent: "")
        history.target = self
        menu.addItem(history)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(AppInfo.displayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func menuOpenAssistant() { trigger() }
    @objc private func menuOpenHistory() {
        settingsController.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            NotificationCenter.default.post(name: .selectHistoryTab, object: nil)
        }
    }

    /// Relaunch the app so a freshly-granted Accessibility permission takes
    /// effect (a running process often won't pick it up until it restarts).
    private func relaunchApp() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.4; /usr/bin/open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Hotkey

    private func configureHotKey() {
        hotKeyManager.onActivate = { [weak self] in self?.trigger() }
        updateHotKeyRegistration()
    }

    private func updateHotKeyRegistration() {
        if appState.settings.hotkeyEnabled {
            hotKeyManager.register()
        } else {
            hotKeyManager.unregister()
        }
    }

    // MARK: - Notifications

    private func registerObservers() {
        let center = NotificationCenter.default
        center.addObserver(forName: .openSettings, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.settingsController.show() }
        }
        center.addObserver(forName: .openHistory, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.settingsController.show()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    NotificationCenter.default.post(name: .selectHistoryTab, object: nil)
                }
            }
        }
        center.addObserver(forName: .hotkeyPreferenceChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updateHotKeyRegistration() }
        }
        center.addObserver(forName: .quitApp, object: nil, queue: .main) { _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    // MARK: - Main menu (enables standard edit shortcuts in text fields)

    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About \(AppInfo.displayName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(AppInfo.displayName)",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu — needed so Cut/Copy/Paste/Select-All/Undo work in fields.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsFromMenu() {
        settingsController.show()
    }
}
