package fr.dtfh.messages

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Composant exigé pour tenir le rôle d'application SMS par défaut.
 *
 * Les MMS ne sont pas gérés : le récepteur existe pour satisfaire la condition
 * du rôle, et laisse passer. Le jour où les MMS seront implémentés, c'est ici
 * que le PDU sera téléchargé puis écrit dans `content://mms`.
 */
class MmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Unit
}
