import Foundation
import SwiftUI

/// Wraps all user-configurable settings via @AppStorage / UserDefaults.
/// Conforms to ObservableObject so SwiftUI views update automatically.
class SettingsManager: ObservableObject {

    // MARK: - Scanning Settings

    /// Whether background BLE scanning is enabled (analogous to Android foreground service toggle).
    @AppStorage("foreground_service")
    var backgroundScanningEnabled: Bool = true

    /// Minimum RSSI (dBm) to report a detection. Devices below this threshold are ignored.
    @AppStorage("rssi_threshold")
    var rssiThreshold: Int = -75

    /// Preferred app language. "system" means follow iOS system setting.
    @AppStorage("app_language")
    var appLanguage: String = "system"

    // MARK: - Notification Settings

    /// Whether to fire local notifications on detection.
    @AppStorage("enable_notifications")
    var notificationsEnabled: Bool = true

    /// Minimum time between notifications in milliseconds. Prevents notification spam.
    @AppStorage("cooldown_ms")
    var cooldownMs: Int = 10000

    // MARK: - Logging Settings

    /// Whether to display detections in the in-app log view.
    @AppStorage("logging_enabled")
    var loggingEnabled: Bool = true

    /// Enables verbose debug logging including all BLE advertisements.
    @AppStorage("debug_enabled")
    var debugEnabled: Bool = false

    /// Maximum number of lines kept in the in-app log buffer.
    @AppStorage("debug_max_lines")
    var maxLogLines: Int = 200

    /// When debug mode is on, only process advertisements that carry manufacturer-specific data.
    @AppStorage("debug_advonly")
    var advOnly: Bool = true

    /// Comma-separated hex company IDs to match in debug mode (e.g. "0x1234, 0x5678").
    @AppStorage("debug_company_ids")
    var debugCompanyIds: String = ""

    // MARK: - Derived Values

    var cooldownSeconds: TimeInterval {
        TimeInterval(cooldownMs) / 1000.0
    }

    /// Parses `debugCompanyIds` string into a set of UInt16 values.
    var parsedDebugCompanyIds: Set<UInt16> {
        guard debugEnabled && !debugCompanyIds.isEmpty else { return [] }
        return Set(
            debugCompanyIds
                .split(separator: ",")
                .compactMap { part -> UInt16? in
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    let hex = trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X")
                        ? String(trimmed.dropFirst(2))
                        : trimmed
                    return UInt16(hex, radix: 16)
                }
        )
    }
}
