import Foundation
import UserNotifications

class NotificationService {

    private var lastNotificationTime: Date?

    // MARK: - Permission

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("NotificationService: permission error — \(error)")
            }
            completion?(granted)
        }
    }

    // MARK: - Detection Notification

    /// Posts a local notification for a detected device, subject to cooldown.
    func scheduleDetectionNotification(for event: DetectionEvent, cooldownSeconds: TimeInterval) {
        // Cooldown check
        if let last = lastNotificationTime {
            guard Date().timeIntervalSince(last) >= cooldownSeconds else { return }
        }
        lastNotificationTime = Date()

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Smart Glasses are maybe nearby"
        let deviceDisplayName = event.deviceName ?? "Unknown Device"
        content.body = "\(deviceDisplayName) detected (RSSI: \(event.rssi) dBm)"
        content.subtitle = "Company: \(event.companyName)"
        content.sound = .default
        content.categoryIdentifier = "DETECTION"

        // Include detection reason in the userInfo for potential future use
        content.userInfo = [
            "deviceIdentifier": event.deviceIdentifier,
            "companyName": event.companyName,
            "reason": event.detectionReason
        ]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationService: failed to schedule notification — \(error)")
            }
        }
    }
}
