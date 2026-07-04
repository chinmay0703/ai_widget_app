import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey (default ⌥Space) using the Carbon hotkey API,
/// which reliably fires regardless of the frontmost app.
final class HotKeyManager {
    /// Called on the main thread when the hotkey is pressed.
    var onActivate: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isRegistered = false

    private let signature: OSType = 0x464C_4149 // 'FLAI'

    func register() {
        guard !isRegistered else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        guard installStatus == noErr else {
            Log.hotkey.error("InstallEventHandler failed: \(installStatus)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_K),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            Log.hotkey.error("RegisterEventHotKey failed: \(registerStatus)")
            return
        }

        isRegistered = true
        Log.hotkey.info("Registered global hotkey ⌘⇧K")
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isRegistered = false
    }

    fileprivate func fire() {
        DispatchQueue.main.async { [weak self] in
            self?.onActivate?()
        }
    }

    deinit {
        unregister()
    }
}

/// C-compatible Carbon callback. Recovers the manager instance from userData.
private func hotKeyEventHandler(nextHandler: EventHandlerCallRef?,
                                event: EventRef?,
                                userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.fire()
    return noErr
}
