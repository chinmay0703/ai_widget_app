import Foundation
import os

/// Thin wrapper over os.Logger so call sites stay terse and consistent.
enum Log {
    private static let subsystem = AppInfo.bundleIdentifier

    static let app = Logger(subsystem: subsystem, category: "app")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let accessibility = Logger(subsystem: subsystem, category: "accessibility")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
}
