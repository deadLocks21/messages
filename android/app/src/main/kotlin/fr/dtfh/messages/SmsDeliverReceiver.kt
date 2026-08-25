package fr.dtfh.messages

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Réception d'un SMS. N'arrive **que** si l'app tient le rôle SMS par défaut :
 * les autres applications reçoivent au mieux `SMS_RECEIVED`, en lecture seule.
 *
 * L'app par défaut a une obligation que le système n'assure plus à sa place :
 * **écrire le message dans le stock**. Sans cette insertion, le SMS n'existe
 * nulle part — ni pour nous, ni pour les autres apps.
 */
class SmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return

        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (parts.isEmpty()) return

        // Un SMS long arrive en plusieurs parties à recoller, dans l'ordre.
        val address = parts.first().displayOriginatingAddress ?: return
        val body = parts.joinToString(separator = "") { it.displayMessageBody.orEmpty() }
        val timestamp = parts.first().timestampMillis.takeIf { it > 0 }
            ?: System.currentTimeMillis()

        val message = runCatching {
            SmsStore(context).insertIncoming(address, body, timestamp)
        }.getOrNull() ?: return

        // L'UI est peut-être ouverte : elle se met à jour sans notification.
        SmsEventBus.emitReceived(message)

        SmsNotifications.notifyIncoming(
            context = context,
            threadId = message["threadId"] as? String ?: "",
            address = address,
            body = body,
        )
    }
}
