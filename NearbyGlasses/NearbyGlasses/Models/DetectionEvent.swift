import Foundation

struct DetectionEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let deviceIdentifier: String  // peripheral.identifier UUID string (NOT a MAC address on iOS)
    let deviceName: String?
    let rssi: Int
    let companyId: UInt16?
    let companyName: String
    let manufacturerDataHex: String?
    let detectionReason: String

    init(
        deviceIdentifier: String,
        deviceName: String?,
        rssi: Int,
        companyId: UInt16?,
        companyName: String,
        manufacturerDataHex: String?,
        detectionReason: String
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.deviceIdentifier = deviceIdentifier
        self.deviceName = deviceName
        self.rssi = rssi
        self.companyId = companyId
        self.companyName = companyName
        self.manufacturerDataHex = manufacturerDataHex
        self.detectionReason = detectionReason
    }

    var formattedLog: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: timestamp)
        let nameStr = deviceName ?? "Unknown Device"
        return "[\(timeStr)] \(nameStr) (\(rssi) dBm) - \(detectionReason)"
    }

    var formattedCompanyId: String {
        guard let cid = companyId else { return "N/A" }
        return String(format: "0x%04X", cid)
    }
}
