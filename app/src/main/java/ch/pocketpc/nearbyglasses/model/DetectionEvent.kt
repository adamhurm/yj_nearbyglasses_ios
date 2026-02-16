package ch.pocketpc.nearbyglasses.model

import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.system.exitProcess

@Parcelize
data class DetectionEvent(
    val timestamp: Long,
    val deviceAddress: String,
    val deviceName: String?,
    val rssi: Int,
    val companyId: String?,
    val companyName: String,
    val manufacturerData: String?,
    val detectionReason: String
) : Parcelable {
    
    fun toJson(): String {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        return """
            {
                "timestamp": $timestamp,
                "timestampFormatted": "${dateFormat.format(Date(timestamp))}",
                "deviceAddress": "$deviceAddress",
                "deviceName": ${deviceName?.let { "\"$it\"" } ?: "null"},
                "rssi": $rssi,
                "companyId": ${companyId?.let { "\"$it\"" } ?: "null"},
                "companyName": "$companyName",
                "manufacturerData": ${manufacturerData?.let { "\"$it\"" } ?: "null"},
                "detectionReason": "$detectionReason"
            }
        """.trimIndent()
    }
    
    fun toLogString(): String {
        val dateFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        val time = dateFormat.format(Date(timestamp))
        return "[$time] ${deviceName ?: "Unknown"} (${rssi}dBm) - $detectionReason"
    }
    
    companion object {
        // Meta Platforms, Inc. (formerly Facebook)
        const val META_COMPANY_ID1 = 0x01AB
        const val META_COMPANY_ID2 = 0x058E

        // EssilorLuxottica - needs more verification, but OAKLEY and some Meta models likely have that
        const val ESSILOR_COMPANY_ID = 0x0D53
        //Snap (Snapchat) Spectacles
        const val SNAP_COMPANY_ID = 0x0D53

        fun isSmartGlasses(
            companyId: Int?,
            deviceName: String?
        ): Pair<Boolean, String> {
            val reasons = mutableListOf<String>()
            
            // Check company ID
            if (companyId == META_COMPANY_ID1) {
                reasons.add("Meta Company ID (0x01AB)")
            }
            if (companyId == META_COMPANY_ID2) {
                reasons.add("Meta Company ID (0x058E)")
            }

            if (companyId == ESSILOR_COMPANY_ID && ESSILOR_COMPANY_ID != 0x0D53) {
                reasons.add("EssilorLuxottica Company ID (0x0D53)")
            }

            if (companyId == SNAP_COMPANY_ID) {
                reasons.add("Snap Company ID (0x03C2 )")
            }
            
            // Check device name
            deviceName?.let { name ->
                val nameLower = name.lowercase()
                when {
                    nameLower.contains("rayban") -> reasons.add("Device name contains 'rayban'")
                    nameLower.contains("ray-ban") -> reasons.add("Device name contains 'ray-ban'")
                    nameLower.contains("ray ban") -> reasons.add("Device name contains 'ray ban'")
                else -> {} // do nothing
                }
            }
            
            return Pair(reasons.isNotEmpty(), reasons.joinToString(", "))
        }
        
        fun getCompanyName(companyId: Int): String {
            return when (companyId) {
                META_COMPANY_ID1 -> "Meta Platforms, Inc."
                META_COMPANY_ID2 -> "Meta Platforms, Inc."
                ESSILOR_COMPANY_ID -> "EssilorLuxottica"
                else -> "Unknown (0x${String.format("%04X", companyId)})"
            }
        }
    }
}
