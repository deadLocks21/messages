package fr.dtfh.messages

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Réception d'un MMS entrant — seconde moitié : le PDU est descendu.
 *
 * Déclaré au **manifeste** et non enregistré à chaud : entre l'annonce du MMS
 * et sa descente il s'écoule un aller-retour réseau, pendant lequel l'app peut
 * très bien ne plus tourner — un receveur lié à un processus vivant ne serait
 * pas là pour recevoir l'accusé, et le message serait perdu alors même qu'il a
 * été téléchargé.
 *
 * `goAsync()` : écrire trois tables et relire le message reçu dépasse le budget
 * d'un `onReceive`, et le travail ne peut pas être remis à plus tard — c'est
 * lui qui fait exister le message.
 */
class MmsDownloadedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val code = resultCode
        Thread {
            try {
                MmsReception.finish(context, intent, code)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
