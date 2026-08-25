package fr.dtfh.messages

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.telephony.PhoneNumberUtils

/**
 * Réponse rapide par SMS depuis l'écran d'appel entrant
 * (`ACTION_RESPOND_VIA_MESSAGE`). Quatrième composant exigé par le rôle
 * d'application SMS par défaut.
 *
 * Le service est démarré sans UI : il envoie le message et s'arrête.
 */
class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val body = intent?.getStringExtra(Intent.EXTRA_TEXT)
        val recipients = intent?.data?.let { uri ->
            PhoneNumberUtils.replaceUnicodeDigits(uri.schemeSpecificPart)
                .split(',', ';')
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        }

        if (!body.isNullOrBlank() && !recipients.isNullOrEmpty()) {
            runCatching {
                SmsStore(applicationContext).sendMessage(recipients, body, null)
            }
        }

        stopSelf(startId)
        return START_NOT_STICKY
    }
}
