import Foundation

struct CompanyDatabase {

    // MARK: - Known Smart Glasses Company IDs (Bluetooth SIG Assigned)

    static let metaCompanyId1: UInt16    = 0x01AB  // Meta Platforms, Inc. (formerly Facebook) — Ray-Ban Meta
    static let metaCompanyId2: UInt16    = 0x058E  // Meta Platforms Technologies, LLC
    static let essilorCompanyId: UInt16  = 0x0D53  // Luxottica Group S.p.A. (EssilorLuxottica) — manufactures Ray-Bans
    static let snapCompanyId: UInt16     = 0x03C2  // Snapchat, Inc. — Snap Spectacles

    static let smartGlassesCompanyIds: Set<UInt16> = [
        metaCompanyId1,
        metaCompanyId2,
        essilorCompanyId,
        snapCompanyId
    ]

    // MARK: - Detection

    /// Returns (isMatch, reason) for a given advertisement.
    /// - Parameters:
    ///   - companyId: parsed little-endian company ID from manufacturer-specific data (may be nil)
    ///   - deviceName: local name from advertisement or peripheral (may be nil)
    ///   - debugCompanyIds: additional IDs to match in debug mode
    static func isSmartGlasses(
        companyId: UInt16?,
        deviceName: String?,
        debugCompanyIds: Set<UInt16> = []
    ) -> (isMatch: Bool, reason: String) {

        // 1. Known company ID match
        if let cid = companyId, smartGlassesCompanyIds.contains(cid) {
            let name = Self.companyName(for: cid)
            return (true, "\(name) Company ID (\(String(format: "0x%04X", cid)))")
        }

        // 2. Device name pattern match (secondary, typically only seen during pairing)
        if let name = deviceName?.lowercased() {
            if name.contains("rayban") {
                return (true, "Device name contains 'rayban'")
            }
            if name.contains("ray-ban") {
                return (true, "Device name contains 'ray-ban'")
            }
            if name.contains("ray ban") {
                return (true, "Device name contains 'ray ban'")
            }
        }

        // 3. Debug override company IDs
        if let cid = companyId, !debugCompanyIds.isEmpty, debugCompanyIds.contains(cid) {
            return (true, "Debug override: Company ID \(String(format: "0x%04X", cid)) matched")
        }

        return (false, "")
    }

    // MARK: - Company Name Lookup

    static func companyName(for id: UInt16) -> String {
        switch id {
        case metaCompanyId1:
            return "Meta Platforms, Inc."
        case metaCompanyId2:
            return "Meta Platforms Technologies, LLC"
        case essilorCompanyId:
            return "EssilorLuxottica"
        case snapCompanyId:
            return "Snapchat, Inc."
        default:
            return String(format: "Unknown (0x%04X)", id)
        }
    }
}
