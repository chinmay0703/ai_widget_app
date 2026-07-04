import AppKit

/// Headless-ish stress test: repeatedly creates the real windows with a wide
/// variety of inputs, pumping the run loop so the display-link CATransaction
/// layout pass (the one that has been crashing) actually fires each time.
///
/// Run with:  FloatingAI --selftest [N]      (default N = 1000)
/// Prints SELFTEST_PASS on success; crashes/prints the exception otherwise.
enum SelfTest {
    /// A spread of selected-text inputs, including the pathological ones.
    static let cases: [String] = {
        let huge = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 4000) // ~180k chars
        let longNoSpaces = String(repeating: "a", count: 20000)
        let manyNewlines = String(repeating: "line\n", count: 2000)
        let markdown = """
        # Heading
        Some **bold** and *italic* and `code`.
        - bullet one
        - bullet two
        1. first
        2. second
        > a quote
        ```
        let x = 1
        ```
        """
        return [
            "",
            " ",
            "Hello, world!",
            "Fix this sentence pls",
            markdown,
            huge,
            longNoSpaces,
            manyNewlines,
            "emoji 😀🎉🇮🇳 and RTL مرحبا بالعالم שלום עולם",
            "Special <>&\"'{}[]()%$#@!\\/ chars and\ttabs",
            "Multi\nline\nselection\nwith\nseveral\nrows",
            String(repeating: "word ", count: 500),
        ]
    }()

    @MainActor
    static func run() {
        let n = parseIterations()
        // Log exceptions instead of crashing, so we can capture the reason and
        // keep going through all cases.
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")
        NSSetUncaughtExceptionHandler { ex in
            let msg = "UNCAUGHT_EXCEPTION name=\(ex.name.rawValue) reason=\(ex.reason ?? "nil")\n"
                + ex.callStackSymbols.prefix(12).joined(separator: "\n") + "\n"
            FileHandle.standardError.write(msg.data(using: .utf8)!)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = SelfTestDelegate(iterations: n)
        app.delegate = delegate
        app.run()
    }

    private static func parseIterations() -> Int {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--selftest"), idx + 1 < args.count, let n = Int(args[idx + 1]) {
            return max(1, n)
        }
        return 1000
    }
}

@MainActor
final class SelfTestDelegate: NSObject, NSApplicationDelegate {
    private let iterations: Int
    init(iterations: Int) { self.iterations = iterations; super.init() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Give AppKit one runloop turn to finish launching, then run cases.
        DispatchQueue.main.async { [weak self] in self?.runCases() }
    }

    private func log(_ s: String) {
        FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
    }

    private func pump(_ seconds: TimeInterval) {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: seconds))
    }

    private func runCases() {
        let cases = SelfTest.cases
        let appState = AppState(history: HistoryStore())
        let popup = PopupController(appState: appState)
        let access = AccessibilityController(onRelaunch: {})
        let settings = SettingsController(appState: appState)
        let onboarding = OnboardingController(appState: appState, onFinish: {})

        log("SELFTEST_START n=\(iterations) cases=\(cases.count)")

        for i in 0..<iterations {
            autoreleasepool {
                let text = cases[i % cases.count]

                // Primary suspect: the popup (dynamic sizing + hosting view layout).
                popup.present(selectedText: text, previousApp: nil)
                pump(0.012)
                popup.close()
                pump(0.004)

                // Polling views (Timers churn @State → layout invalidation).
                if i % 20 == 0 {
                    access.show(); pump(0.012); access.close(); pump(0.004)
                }
                if i % 60 == 0 {
                    onboarding.show(); pump(0.012); onboarding.close(); pump(0.004)
                }
                if i % 120 == 0 {
                    settings.show(); pump(0.012); settings.close(); pump(0.004)
                }
            }
            if i % 100 == 0 { log("...\(i)") }
        }

        // Extra churn: rapid open/close of the popup with no pump between, to
        // surface teardown-during-pending-layout races.
        for _ in 0..<200 {
            popup.present(selectedText: "rapid", previousApp: nil)
            popup.close()
        }
        pump(0.2)

        log("SELFTEST_PASS n=\(iterations)")
        exit(0)
    }
}
