import AppKit

/// Entry point. The app runs as an accessory (no Dock icon); the activation
/// policy and everything else is configured in `AppDelegate`.
@main
enum FloatingAIMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()   // sets up its own app + delegate, then exits
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // `run()` blocks for the lifetime of the app, keeping `delegate` (a
        // weak reference on NSApplication) alive.
        application.run()
    }
}
