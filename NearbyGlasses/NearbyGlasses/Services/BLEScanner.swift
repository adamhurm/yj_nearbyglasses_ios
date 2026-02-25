import Foundation
import CoreBluetooth

// CoreBluetooth option key string literals (top-level constants removed in Xcode 16 / Swift 6).
// The string values match the underlying Objective-C constants.
private let kRestoreIdentifierKey = "kCBCentralManagerOptionRestoreStateIdentifierKey"
private let kRestoredStateScanOptionsKey = "kCBCentralManagerRestoredStateScanOptionsKey"
private let kScanOptionAllowDuplicatesKey = "kCBCentralManagerScanOptionAllowDuplicatesKey"

// MARK: - Delegate Protocol

protocol BLEScannerDelegate: AnyObject {
    /// Called when a smart glasses device is detected.
    func bleScannerDidDetect(_ event: DetectionEvent)
    /// Called with debug/informational log messages.
    func bleScannerDidLog(_ message: String)
    /// Called when scanning state changes.
    func bleScannerStateChanged(isScanning: Bool)
    /// Called when the CoreBluetooth state changes (e.g. Bluetooth turned off).
    func bleScannerBluetoothStateChanged(_ state: CBManagerState)
}

// MARK: - BLEScanner

/// Wraps CBCentralManager and replicates the Android BluetoothScanner detection logic.
///
/// Key iOS/CoreBluetooth notes:
/// - iOS does NOT expose MAC addresses; `peripheral.identifier` is a per-device local UUID.
/// - `kCBCentralManagerScanOptionAllowDuplicatesKey: true` is required to receive repeated
///   advertisements from the same device (equivalent to Android's MATCH_NUM_MAX_ADVERTISEMENT).
///   In background this key is ignored — iOS coalesces per ~30s.
/// - Manufacturer-specific data from `CBAdvertisementDataManufacturerDataKey` includes the
///   2-byte Company ID prefix (little-endian) followed by the payload.
/// - CBCentralManager state restoration allows iOS to relaunch the app for BLE events.
final class BLEScanner: NSObject {

    weak var delegate: BLEScannerDelegate?

    private var centralManager: CBCentralManager!
    private let settings: SettingsManager
    private let queue = DispatchQueue(label: "com.nearbyglasses.ble", qos: .background)

    private(set) var isScanning = false

    // MARK: - Init

    init(settings: SettingsManager) {
        self.settings = settings
        super.init()
        // State restoration identifier enables iOS to relaunch the app after suspension.
        centralManager = CBCentralManager(
            delegate: self,
            queue: queue,
            options: [kRestoreIdentifierKey: "com.nearbyglasses.scanner"]
        )
    }

    // MARK: - Scanning Control

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            delegate?.bleScannerDidLog("Cannot start scan: Bluetooth state is \(centralManager.state.description)")
            return
        }
        // allowDuplicates: true is essential — without it, each device is only seen once.
        // In background mode iOS ignores this flag (each device seen ~once per 30s anyway).
        let options: [String: Any] = [kScanOptionAllowDuplicatesKey: true]
        centralManager.scanForPeripherals(withServices: nil, options: options)
        isScanning = true
        delegate?.bleScannerStateChanged(isScanning: true)
        delegate?.bleScannerDidLog("Scanning started.")
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        delegate?.bleScannerStateChanged(isScanning: false)
        delegate?.bleScannerDidLog("Scanning stopped.")
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEScanner: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.bleScannerBluetoothStateChanged(central.state)
        switch central.state {
        case .poweredOn:
            // If we were scanning before a state change (e.g. background restoration), restart.
            if isScanning {
                startScanning()
            }
        case .poweredOff:
            isScanning = false
            delegate?.bleScannerStateChanged(isScanning: false)
            delegate?.bleScannerDidLog("Bluetooth powered off — scanning stopped.")
        case .unauthorized:
            isScanning = false
            delegate?.bleScannerStateChanged(isScanning: false)
            delegate?.bleScannerDidLog("Bluetooth access not authorized.")
        case .unsupported:
            delegate?.bleScannerDidLog("Bluetooth LE is not supported on this device.")
        default:
            break
        }
    }

    /// Called when iOS restores CBCentralManager state after the app is relaunched.
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // If the system was scanning before the app was suspended/relaunched, resume scanning.
        if dict[kRestoredStateScanOptionsKey] != nil {
            isScanning = true
        }
    }

    /// Core detection callback — called for every BLE advertisement received.
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssi = RSSI.intValue

        // ── Step 1: RSSI threshold filter ──────────────────────────────────────
        guard rssi >= settings.rssiThreshold else { return }

        // ── Step 2: Extract manufacturer-specific data ──────────────────────────
        let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data

        // ── Step 3: Parse Company ID (little-endian, first 2 bytes) ─────────────
        var companyId: UInt16?
        var manufacturerDataHex: String?

        if let data = mfgData, data.count >= 2 {
            companyId = UInt16(data[0]) | (UInt16(data[1]) << 8)
            manufacturerDataHex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        }

        // ── Step 4: Extract device name ─────────────────────────────────────────
        let deviceName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name

        // ── Step 5: Debug ADV-only filter ───────────────────────────────────────
        // In debug + advOnly mode, skip advertisements without manufacturer data.
        if settings.debugEnabled && settings.advOnly && mfgData == nil {
            return
        }

        // ── Step 6: Debug logging ────────────────────────────────────────────────
        if settings.debugEnabled {
            let idStr = companyId.map { String(format: "0x%04X", $0) } ?? "none"
            let msg = "DEBUG: ADV addr=\(peripheral.identifier.uuidString) name=\(deviceName ?? "?") rssi=\(rssi) companyId=\(idStr) len=\(mfgData?.count ?? 0)"
            delegate?.bleScannerDidLog(msg)
        }

        // ── Step 7: Smart glasses matching ──────────────────────────────────────
        let debugIds = settings.parsedDebugCompanyIds
        let (isMatch, reason) = CompanyDatabase.isSmartGlasses(
            companyId: companyId,
            deviceName: deviceName,
            debugCompanyIds: debugIds
        )

        guard isMatch else { return }

        // ── Step 8: Build and emit DetectionEvent ────────────────────────────────
        let resolvedCompanyName: String
        if let cid = companyId {
            resolvedCompanyName = CompanyDatabase.companyName(for: cid)
        } else {
            resolvedCompanyName = "Unknown"
        }

        let event = DetectionEvent(
            deviceIdentifier: peripheral.identifier.uuidString,
            deviceName: deviceName,
            rssi: rssi,
            companyId: companyId,
            companyName: resolvedCompanyName,
            manufacturerDataHex: manufacturerDataHex,
            detectionReason: reason
        )

        delegate?.bleScannerDidDetect(event)
    }
}

// MARK: - CBManagerState Description

private extension CBManagerState {
    var description: String {
        switch self {
        case .unknown:      return "unknown"
        case .resetting:    return "resetting"
        case .unsupported:  return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff:   return "poweredOff"
        case .poweredOn:    return "poweredOn"
        @unknown default:   return "unknown(\(rawValue))"
        }
    }
}
