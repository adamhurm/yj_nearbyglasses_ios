package ch.pocketpc.nearbyglasses.util

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import ch.pocketpc.nearbyglasses.MainActivity
import ch.pocketpc.nearbyglasses.R
import ch.pocketpc.nearbyglasses.model.DetectionEvent

class NotificationHelper(private val context: Context) {
    
    private val notificationManager = NotificationManagerCompat.from(context)
    
    companion object {
        const val CHANNEL_ID_DETECTION = "glasses_detection"
        const val CHANNEL_ID_SERVICE = "glasses_service"
        const val NOTIFICATION_ID_DETECTION = 1001
        const val NOTIFICATION_ID_SERVICE = 1002
    }
    
    init {
        createNotificationChannels()
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Detection channel (high priority)
            val detectionChannel = NotificationChannel(
                CHANNEL_ID_DETECTION,
                "Smart Glasses Detection Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when smart glasses are detected"
                enableVibration(true)
                setShowBadge(true)
            }
            
            // Service channel (low priority)
            val serviceChannel = NotificationChannel(
                CHANNEL_ID_SERVICE,
                "Background Scanning Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when the app is scanning in the background"
                setShowBadge(false)
            }
            
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(detectionChannel)
            manager.createNotificationChannel(serviceChannel)
        }
    }
    
    fun showDetectionNotification(event: DetectionEvent) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_DETECTION)
            .setSmallIcon(R.drawable.ic_warning)

            .setContentTitle(context.getString(R.string.notifyText)) //@string/notifyText
            .setContentText("${event.deviceName ?: "Unknown device"} detected (RSSI: ${event.rssi} dBm)")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(buildString {
                        append("Device: ${event.deviceName ?: "Unknown"}\n")
                        append("RSSI: ${event.rssi} dBm\n")
                        append("Reason: ${event.detectionReason}\n")
                        append("Company: ${event.companyName}")
                    })
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
        
        notificationManager.notify(NOTIFICATION_ID_DETECTION, notification)
    }
    
    fun createServiceNotification(): android.app.Notification {
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(context, CHANNEL_ID_SERVICE)
            .setSmallIcon(R.drawable.ic_bluetooth_searching)
            .setContentTitle("Scanning for smart glasses nearby")
            .setContentText("Background scanning is active")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }
}
