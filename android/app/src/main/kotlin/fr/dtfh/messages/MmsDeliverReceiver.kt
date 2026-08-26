package fr.dtfh.messages

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Composant exigé pour tenir le rôle d'application SMS par défaut.
 *
 * L'**envoi** de MMS est géré (cf. [MmsStore]), et le stock `content://mms` est
 * lu comme celui des SMS. La **réception**, elle, ne l'est pas encore : ce que
 * porte `WAP_PUSH_DELIVER` n'est pas le message mais une notification de
 * dépôt (`M-Notification.ind`), qu'il faut décoder puis suivre d'un
 * téléchargement HTTP du PDU auprès du MMSC, sur le réseau de données de
 * l'opérateur — un chemin à part entière, sans rapport avec l'encodeur d'envoi.
 *
 * Le récepteur laisse donc passer. C'est ici que le décodage viendra se
 * brancher, pour écrire le message reçu dans `content://mms` — le reste de
 * l'app saura déjà l'afficher.
 */
class MmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Unit
}
