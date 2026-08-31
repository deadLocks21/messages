package fr.dtfh.messages

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Réception d'un MMS entrant — première moitié du chemin.
 *
 * `WAP_PUSH_DELIVER` n'arrive qu'à l'application SMS par défaut, et personne
 * ne prend le relais si elle n'en fait rien : ce qu'elle laisse tomber ici est
 * perdu pour de bon.
 *
 * Ce que porte l'intent n'est pas le message mais une **notification de
 * dépôt** (`M-Notification.ind`, extra `"data"`) : l'adresse où le MMSC tient
 * le message à disposition. Il faut donc le décoder, puis le télécharger — ce
 * que fait [MmsReception.start], sans attendre : un `onReceive` ne dispose que
 * de quelques secondes, et le résultat reviendra à [MmsDownloadedReceiver].
 */
class MmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        MmsReception.start(context, intent)
    }
}
