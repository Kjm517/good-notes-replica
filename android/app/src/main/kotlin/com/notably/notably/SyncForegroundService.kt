package com.notably.notably

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// Keeps the process alive while a PDF is still uploading or downloading so
/// leaving Notably for another app does not freeze the transfer.
class SyncForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "File sync",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shown while Notably uploads or downloads files"
                    setShowBadge(false)
                },
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Notably")
            .setContentText("Syncing files in the background")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "notably_sync"
        const val NOTIFICATION_ID = 42
    }
}
