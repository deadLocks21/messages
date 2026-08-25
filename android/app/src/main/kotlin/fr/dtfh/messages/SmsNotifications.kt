package fr.dtfh.messages

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Notification d'un SMS entrant.
 *
 * Une application SMS par défaut est seule responsable de prévenir
 * l'utilisateur : le système ne notifie plus rien à sa place. Une notification
 * par fil (le `thread_id` sert de tag), remplacée à chaque nouveau message.
 */
object SmsNotifications {
    private const val CHANNEL_ID = "sms"
    private const val CHANNEL_NAME = "Messages SMS"

    fun notifyIncoming(context: Context, threadId: String, address: String, body: String) {
        ensureChannel(context)

        // Ouvre l'app sur le fil concerné. `sms:` est l'URI que sait déjà
        // recevoir MainActivity (filtre du rôle SMS).
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("sms:$address")).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            threadId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(address)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        // POST_NOTIFICATIONS peut être refusée (API 33+) : on ne fait pas tomber
        // la réception pour autant, le message est déjà dans le stock.
        runCatching {
            NotificationManagerCompat.from(context)
                .notify(threadId, threadId.hashCode(), notification)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Nouveaux messages reçus"
                enableVibration(true)
            }
        )
    }
}
