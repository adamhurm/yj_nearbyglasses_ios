import Foundation
import CoreBluetooth
import SwiftUI

/// Central view model that owns the BLE scanner and notification service.
/// All published properties are updated on the main actor.
@MainActor
final class ScannerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isScanning = false
    @Published var logLines: [String] = []
    @Published var bluetoothUnavailableReason: String?

    // MARK: - Services

    let settings: SettingsManager
    private let bleScanner: BLEScanner
    private let notificationService: NotificationService

    // MARK: - Init

    init() {
        let settings = SettingsManager()
        self.settings = settings
        self.notificationService = NotificationService()
        self.bleScanner = BLEScanner(settings: settings)
        // Wire up delegate after both are created
        bleScanner.delegate = self
    }

    // MARK: - Scanning Control

    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }

    func startScanning() {
        notificationService.requestPermission()
        bleScanner.startScanning()
    }

    func stopScanning() {
        bleScanner.stopScanning()
    }

    // MARK: - Log Management

    func clearLog() {
        logLines = []
    }

    var logText: String {
        logLines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func appendLog(_ line: String) {
        guard settings.loggingEnabled else { return }
        logLines.append(line)
        let max = settings.maxLogLines
        if logLines.count > max {
            logLines.removeFirst(logLines.count - max)
        }
    }
}

// MARK: - BLEScannerDelegate

extension ScannerViewModel: BLEScannerDelegate {

    nonisolated func bleScannerDidDetect(_ event: DetectionEvent) {
        Task { @MainActor in
            self.appendLog(event.formattedLog)
            if self.settings.notificationsEnabled {
                self.notificationService.scheduleDetectionNotification(
                    for: event,
                    cooldownSeconds: self.settings.cooldownSeconds
                )
            }
        }
    }

    nonisolated func bleScannerDidLog(_ message: String) {
        Task { @MainActor in
            self.appendLog(message)
        }
    }

    nonisolated func bleScannerStateChanged(isScanning: Bool) {
        Task { @MainActor in
            self.isScanning = isScanning
        }
    }

    nonisolated func bleScannerBluetoothStateChanged(_ state: CBManagerState) {
        Task { @MainActor in
            switch state {
            case .poweredOn:
                self.bluetoothUnavailableReason = nil
            case .poweredOff:
                self.bluetoothUnavailableReason = "Bluetooth is turned off. Enable it in Settings to scan."
            case .unauthorized:
                self.bluetoothUnavailableReason = "Bluetooth access denied. Allow in Settings > Privacy > Bluetooth."
            case .unsupported:
                self.bluetoothUnavailableReason = "Bluetooth LE is not supported on this device."
            default:
                break
            }
        }
    }
}
