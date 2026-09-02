package fr.dtfh.messages

import android.content.Context
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager

/**
 * Le numéro de notre propre ligne — quand l'appareil le connaît.
 *
 * Il ne le connaît pas toujours : le MSISDN n'est pas gravé dans la SIM, il est
 * *provisionné* par l'opérateur, et nombre de cartes le laissent vide. C'est
 * déjà pour cette raison que [MmsPdu] laisse le `From` d'un envoi au MMSC au
 * lieu de l'écrire.
 *
 * Il sert ici à une seule chose : retirer notre adresse de la liste des
 * destinataires d'un MMS reçu, puisque le fil se compose des **autres**. D'où
 * un `null` assumé plutôt qu'une valeur devinée — [MmsParticipants] sait quoi
 * en faire.
 *
 * Deux sources, dans cet ordre : l'API dédiée d'Android 13, puis le
 * `line1Number` d'avant, que des appareils renseignent encore. Les deux sont
 * protégées par des permissions (`READ_PHONE_NUMBERS`, `READ_SMS`) et lèvent
 * volontiers une `SecurityException` selon la version — d'où le `runCatching`
 * sur chacune : ne pas savoir son numéro n'est pas une raison de perdre un MMS.
 */
object SelfNumber {

    fun of(context: Context, subscriptionId: Int?): String? {
        val subId = subscriptionId?.takeIf { it >= 0 } ?: smsSubscriptionId()
        return fromSubscriptionManager(context, subId)
            ?: fromTelephonyManager(context, subId)
    }

    /** Android 13+ : l'API faite pour ça. Rend une chaîne **vide** si rien. */
    private fun fromSubscriptionManager(context: Context, subId: Int): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return null
        return runCatching {
            context.getSystemService(SubscriptionManager::class.java)
                ?.getPhoneNumber(subId)
                ?.takeIf { it.isNotEmpty() }
        }.getOrNull()
    }

    /** Repli d'avant Android 13, déprécié mais toujours servi par beaucoup. */
    @Suppress("DEPRECATION")
    private fun fromTelephonyManager(context: Context, subId: Int): String? = runCatching {
        val manager = context.getSystemService(TelephonyManager::class.java)
            ?.let { if (subId >= 0) it.createForSubscriptionId(subId) else it }
        manager?.line1Number?.takeIf { it.isNotEmpty() }
    }.getOrNull()

    private fun smsSubscriptionId(): Int = runCatching {
        SubscriptionManager.getDefaultSmsSubscriptionId()
    }.getOrDefault(SubscriptionManager.INVALID_SUBSCRIPTION_ID)
}
