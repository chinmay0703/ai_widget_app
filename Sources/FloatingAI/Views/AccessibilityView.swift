import SwiftUI

/// Shown when the app needs Accessibility permission. Explains the grant,
/// opens System Settings, watches for the change, and offers a reliable
/// "Restart" — because a running app often only sees a new Accessibility
/// grant after it relaunches.
struct AccessibilityView: View {
    var onOpenSettings: () -> Void
    var onRelaunch: () -> Void
    var onClose: () -> Void

    @State private var trusted = AccessibilityService.isTrusted
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: trusted ? "checkmark.shield.fill" : "hand.raised.fill")
                .font(.system(size: 44))
                .foregroundStyle(trusted ? .green : .orange)

            Text(trusted ? "Accessibility Enabled" : "Enable Accessibility")
                .font(.title2).bold()

            Text("Floating AI needs Accessibility permission to read the text you select and to paste answers back into your apps.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: trusted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(trusted ? .green : .secondary)
                Text(trusted ? "Permission granted — restart to finish." : "Waiting for permission…")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            VStack(spacing: 8) {
                if !trusted {
                    Button(action: onOpenSettings) {
                        Label("Open Accessibility Settings", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
                Button(action: onRelaunch) {
                    Label("Restart Floating AI", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .tint(trusted ? .green : .accentColor)
            }
            .frame(maxWidth: 280)

            Button("Later", action: onClose)
                .buttonStyle(.link)

            Text("Tip: after enabling the switch in System Settings, click “Restart Floating AI”.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 420)
        .onReceive(poll) { _ in trusted = AccessibilityService.isTrusted }
    }
}
