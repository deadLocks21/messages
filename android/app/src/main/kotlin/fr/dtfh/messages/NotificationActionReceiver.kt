package fr.dtfh.messages

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

/**
 * Actions déclenchées depuis la notification : **répondre directement** et
 * **marquer comme lu**.
 *
 * Déclaré au manifeste (et non enregistré dynamiquement) parce qu'il doit
 * fonctionner alors que l'app n'est pas lancée — c'est justement le cas d'usage
 * d'une réponse depuis le volet de notifications.
 */
class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        private const val ACTION_REPLY = "fr.dtfh.messages.NOTIFICATION_REPLY"
        private const val ACTION_MARK_READ = "fr.dtfh.messages.NOTIFICATION_MARK_READ"
        private const val EXTRA_THREAD_ID = "threadId"
        private const val EXTRA_ADDRESS = "address"

        fun replyIntent(context: Context, threadId: String, address: String) =
            Intent(context, NotificationActionReceiver::class.java).apply {
                action = ACTION_REPLY
                putExtra(EXTRA_THREAD_ID, threadId)
                putExtra(EXTRA_ADDRESS, address)
            }

        fun markReadIntent(context: Context, threadId: String) =
            Intent(context, NotificationActionReceiver::class.java).apply {
                action = ACTION_MARK_READ
                putExtra(EXTRA_THREAD_ID, threadId)
            }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val threadId = intent.getStringExtra(EXTRA_THREAD_ID) ?: return
        val store = SmsStore(context)

        when (intent.action) {
            ACTION_REPLY -> {
                val address = intent.getStringExtra(EXTRA_ADDRESS) ?: return
                val reply = RemoteInput.getResultsFromIntent(intent)
                    ?.getCharSequence(SmsNotifications.REMOTE_INPUT_KEY)
                    ?.toString()
                    ?.trim()
                if (reply.isNullOrEmpty()) return

                // Un envoi refusé (plus l'app par défaut, SIM absente) ne doit pas
                // faire tomber le process de notification : la notification reste
                // en place, l'utilisateur retentera depuis l'app.
                val sent = runCatching { store.sendMessage(listOf(address), reply, null) }
                if (sent.isFailure) return

                // Répondre vaut lecture du fil.
                runCatching { store.markThreadRead(threadId) }
                SmsNotifications.refreshAfterReply(context, threadId, address)
                SmsEventBus.emitChanged()
            }

            ACTION_MARK_READ -> {
                runCatching { store.markThreadRead(threadId) }
                SmsNotifications.cancel(context, threadId)
                SmsEventBus.emitChanged()
            }
        }
    }
}
