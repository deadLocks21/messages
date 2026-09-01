package fr.dtfh.messages

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Issue d'un envoi : dépôt réseau du SMS, remise au destinataire, dépôt du MMS
 * auprès du MMSC.
 *
 * Déclaré au manifeste, et non enregistré à chaud par [SmsBridge] comme il
 * l'était : entre le geste d'envoi et l'accusé il s'écoule un aller-retour
 * réseau, pendant lequel l'utilisateur a très bien pu quitter l'application.
 * Un receveur lié à l'`Activity` laissait alors le message figé sur « Envoi… »
 * dans le stock, sans que rien ne le dise jamais — et c'est précisément quand
 * on n'est plus devant l'écran qu'un échec doit se signaler.
 *
 * Le receveur tourne dans le processus de l'app : quand celle-ci est ouverte,
 * [SmsEventBus] republie l'état vers Dart et le fil se met à jour en direct ;
 * quand elle ne l'est pas, l'émission ne trouve personne, et il reste la
 * notification.
 */
class SmsSendStatusReceiver : BroadcastReceiver() {

    companion object {
        /**
         * L'accusé que le système rendra pour ce message.
         *
         * Le composant est **explicite** : un simple `setPackage` suffirait à
         * la livraison, mais nommer la classe est ce qui permet au receveur de
         * rester non exporté tout en étant joignable par un `PendingIntent`
         * que le processus téléphonie déclenche.
         *
         * Le SMS a deux accusés — dépôt puis remise — là où le MMS n'en a
         * qu'un : son PDU part vers le MMSC, et c'est tout ce que l'opérateur
         * rend.
         */
        fun pendingIntent(
            context: Context,
            action: String,
            messageId: String,
            threadId: String,
        ): PendingIntent {
            val intent = Intent(context, SmsSendStatusReceiver::class.java).apply {
                setAction(action)
                putExtra(SmsStore.EXTRA_MESSAGE_ID, messageId)
                putExtra(SmsStore.EXTRA_THREAD_ID, threadId)
            }
            return PendingIntent.getBroadcast(
                context,
                // Un code distinct par (message, action) : sans cela deux envois
                // simultanés partageraient le même PendingIntent et donc les mêmes
                // extras.
                (messageId + action).hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val messageId = intent.getStringExtra(SmsStore.EXTRA_MESSAGE_ID) ?: return
        val threadId = intent.getStringExtra(SmsStore.EXTRA_THREAD_ID).orEmpty()
        val delivered = intent.action == SmsStore.ACTION_SMS_DELIVERED
        val success = resultCode == Activity.RESULT_OK
        val store = SmsStore(context)
        val status = runCatching {
            store.applySendResult(messageId, delivered = delivered, success = success)
        }.getOrDefault(if (success) "sent" else "failed")

        SmsEventBus.emitStatus(messageId, threadId, status)
        // Le stock a changé de forme, pas seulement d'état : un MMS passé en
        // « envoyé » sort de la boîte d'envoi.
        if (MmsStore.isMmsId(messageId)) SmsEventBus.emitChanged()

        // Seul le **dépôt** manqué se notifie. Un accusé de remise négatif
        // existe aussi, mais il porte sur un message que le réseau a bien
        // accepté : la bulle en rend compte, sans qu'il faille sortir
        // l'utilisateur de ce qu'il fait.
        if (!success && !delivered) notifyFailure(context, store, messageId, threadId)
    }

    private fun notifyFailure(
        context: Context,
        store: SmsStore,
        messageId: String,
        threadId: String,
    ) {
        val message = runCatching { store.getMessage(messageId) }.getOrNull()
        SmsNotifications.notifySendFailure(
            context,
            threadId = threadId,
            address = message?.get("address") as? String ?: "",
            body = message?.get("body") as? String ?: "",
        )
    }
}
