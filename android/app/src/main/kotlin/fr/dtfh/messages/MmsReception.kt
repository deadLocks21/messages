package fr.dtfh.messages

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import java.util.UUID

/**
 * Réception d'un MMS, de la notification de dépôt au message écrit au stock.
 *
 * Le chemin tient en deux temps, séparés par le réseau :
 *
 * 1. [start] — appelé par [MmsDeliverReceiver] sur `WAP_PUSH_DELIVER`. Il
 *    décode le `M-Notification.ind`, prépare un fichier vide derrière le
 *    `FileProvider` et lance `downloadMultimediaMessage`. Il ne **télécharge
 *    pas** : il demande, et rend la main tout de suite.
 * 2. [finish] — appelé par [MmsDownloadedReceiver] quand le service MMS du
 *    système a fini. Il relit le fichier, décode le `M-Retrieve.conf`, écrit le
 *    message et prévient.
 *
 * ### Pourquoi rien n'est écrit avant le téléchargement
 *
 * L'autre option — écrire tout de suite la notification (`MESSAGE_TYPE = 130`)
 * puis la compléter — ne perd jamais rien, mais laisse dans le fil une bulle
 * vide que le reste de l'app ne sait pas présenter : `MmsStore` lit des
 * parties, et une notification n'en a aucune. Il faudrait donc un état « en
 * cours de réception » dans le domaine, l'UI qui va avec, et un geste pour
 * relancer — pour un cas qui ne survient qu'en cas d'échec réseau. Le message
 * n'est donc écrit **qu'une fois descendu**, et un échec se lit dans le
 * journal ([TAG]) plutôt que dans le fil.
 *
 * ### Le téléchargement est automatique, sans condition
 *
 * Ni seuil de taille ni condition de réseau : conditionner supposerait un
 * moyen de déclencher le téléchargement à la main, donc une UI qui n'existe
 * pas — et un MMS retenu serait un MMS perdu. C'est aussi ce que fait Google
 * Messages par défaut. Le service MMS du système active de lui-même l'APN de
 * l'opérateur ; le Wi-Fi n'y change rien.
 */
object MmsReception {

    /**
     * Le seul tag de journal du code natif.
     *
     * Tout le reste de l'app journalise en Dart, vers Signoz — inaccessible
     * depuis un receveur qui s'exécute app éteinte, ce qui est précisément le
     * cas ici. Un échec de téléchargement muet serait indébogable : `adb logcat
     * -s Mms` est le seul fil à tirer quand un MMS n'arrive pas.
     */
    const val TAG = "Mms"

    /** Action de l'accusé de téléchargement, rendue par le service MMS. */
    const val ACTION_MMS_DOWNLOADED = "fr.dtfh.messages.MMS_DOWNLOADED"

    const val EXTRA_SENDER = "sender"
    const val EXTRA_SUBSCRIPTION = "subscription"
    const val EXTRA_FILE_URI = "fileUri"

    /** Extras de `WAP_PUSH_DELIVER` — le PDU brut et l'abonnement. */
    private const val EXTRA_PUSH_DATA = "data"
    private const val EXTRA_PUSH_SUBSCRIPTION = "subscription"

    /**
     * Paquet qui héberge le service MMS d'AOSP. C'est lui qui ouvrira notre
     * fichier en écriture, sous **son** identité : sans permission d'URI
     * explicite, le téléchargement échoue — et il échoue en silence, le service
     * ne rendant qu'un code d'erreur générique.
     */
    private const val MMS_SERVICE_PACKAGE = "com.android.phone"

    /** Décode la notification de dépôt et lance le téléchargement. */
    fun start(context: Context, intent: Intent) {
        val pdu = intent.getByteArrayExtra(EXTRA_PUSH_DATA)
        if (pdu == null || pdu.isEmpty()) {
            Log.w(TAG, "WAP_PUSH_DELIVER sans PDU")
            return
        }
        val subscriptionId = intent.getIntExtra(EXTRA_PUSH_SUBSCRIPTION, -1)

        val notification = MmsPduReader.readNotification(pdu) {
            Log.e(TAG, "M-Notification.ind (${pdu.size} o) : $it")
        }
        if (notification == null) {
            Log.w(TAG, "MMS annoncé mais illisible : abandon")
            return
        }
        Log.i(
            TAG,
            "MMS annoncé : ${notification.messageSize} octets, " +
                "transaction ${notification.transactionId}",
        )

        // Le transaction-id nomme le fichier : c'est ce qui appartient à cet
        // échange-là. Absent (certains MMSC ne le posent pas), un identifiant
        // tiré au sort fait l'affaire — il ne sert qu'à ne pas collisionner.
        val transactionId = notification.transactionId
            ?.replace(Regex("[^A-Za-z0-9_-]"), "")
            ?.takeIf { it.isNotEmpty() }
            ?: UUID.randomUUID().toString()

        val store = MmsStore(context)
        val fileUri = runCatching { store.createDownloadFile(transactionId) }
            .getOrElse {
                Log.e(TAG, "fichier de réception impossible à créer", it)
                return
            }

        runCatching {
            context.grantUriPermission(
                MMS_SERVICE_PACKAGE,
                fileUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }.onFailure {
            // Sans cette permission le service télécharge dans le vide et ne
            // rend qu'un code d'erreur générique : c'est *ici* qu'il faut le
            // dire, pas trois lignes de journal plus loin.
            Log.e(TAG, "permission d'écriture refusée à $MMS_SERVICE_PACKAGE", it)
        }

        val downloaded = Intent(ACTION_MMS_DOWNLOADED).apply {
            setClass(context, MmsDownloadedReceiver::class.java)
            putExtra(EXTRA_SENDER, notification.from.orEmpty())
            putExtra(EXTRA_SUBSCRIPTION, subscriptionId)
            putExtra(EXTRA_FILE_URI, fileUri.toString())
        }
        val pending = PendingIntent.getBroadcast(
            context,
            transactionId.hashCode(),
            downloaded,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        runCatching {
            smsManager(context, subscriptionId).downloadMultimediaMessage(
                context,
                notification.contentLocation,
                fileUri,
                null,
                pending,
            )
        }.onSuccess {
            // Sans cette ligne, un `PendingIntent` qui ne revient jamais — APN
            // indisponible, service MMS qui abandonne en silence — est
            // indiscernable d'une demande jamais partie. Seul l'hôte du MMSC
            // est journalisé : le reste de l'URL désigne un message précis.
            Log.i(
                TAG,
                "téléchargement demandé à ${hostOf(notification.contentLocation)} " +
                    "(abonnement $subscriptionId)",
            )
        }.onFailure {
            Log.e(TAG, "téléchargement refusé au démarrage", it)
        }
    }

    /** L'hôte d'une URL, ou son défaut. Jamais le chemin : il nomme le message. */
    private fun hostOf(url: String): String =
        runCatching { Uri.parse(url).host }.getOrNull() ?: "MMSC inconnu"


    /** Relit le PDU téléchargé, l'écrit au stock, notifie. */
    fun finish(context: Context, intent: Intent, resultCode: Int) {
        val fileUri = intent.getStringExtra(EXTRA_FILE_URI)?.let(Uri::parse)
        if (fileUri == null) {
            Log.w(TAG, "accusé de téléchargement sans fichier")
            return
        }
        // La permission accordée au service ne sert plus, quoi qu'il advienne.
        runCatching { context.revokeUriPermission(fileUri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION) }

        if (resultCode != android.app.Activity.RESULT_OK) {
            Log.e(TAG, "téléchargement échoué (code $resultCode)")
            return
        }

        val store = MmsStore(context)
        val pdu = store.consumeDownloadFile(fileUri)
        if (pdu == null) {
            Log.e(TAG, "PDU téléchargé vide ou illisible")
            return
        }

        val retrieved = MmsPduReader.readRetrieveConf(pdu) {
            Log.e(TAG, "M-Retrieve.conf (${pdu.size} o) : $it")
        }
        if (retrieved == null) {
            Log.e(TAG, "MMS téléchargé mais illisible : abandon")
            return
        }
        Log.i(TAG, "M-Retrieve.conf décodé : ${retrieved.parts.size} partie(s)")

        // L'expéditeur du PDU fait foi ; celui de la notification n'est qu'un
        // repli, certains MMSC ne le posant pas.
        if (retrieved.from == null) {
            Log.w(TAG, "M-Retrieve.conf sans From : repli sur celui de la notification")
        }
        val sender = (retrieved.from ?: intent.getStringExtra(EXTRA_SENDER))
            ?.let(MmsPduReader::stripAddressType)
            ?.takeIf { it.isNotEmpty() }
        if (sender == null) {
            Log.e(TAG, "MMS sans expéditeur : impossible de le ranger dans un fil")
            return
        }

        val subscriptionId =
            intent.getIntExtra(EXTRA_SUBSCRIPTION, -1).takeIf { it >= 0 }
        val message = runCatching {
            store.insertIncoming(sender, retrieved, subscriptionId)
        }.getOrElse {
            Log.e(TAG, "écriture du MMS reçu refusée par le provider", it)
            return
        }
        if (message == null) {
            Log.e(TAG, "écriture du MMS reçu refusée par le provider")
            return
        }

        val threadId = message["threadId"] as? String ?: ""
        val body = message["body"] as? String ?: ""
        val date = message["date"] as? Long ?: System.currentTimeMillis()
        // Le stock est relu, pas cru sur parole : les écritures de parties sont
        // individuellement tolérantes (cf. `MmsStore`), et une ligne de succès
        // qui annoncerait ce qu'on a *voulu* écrire masquerait exactement le
        // cas qu'on cherche — une bulle qui arrive vide.
        val written = (message["attachments"] as? List<*>)?.size ?: 0
        val expected = retrieved.parts.count { !it.isSmil && !it.isText }
        if (written != expected) {
            Log.e(
                TAG,
                "MMS ${message["id"]} : $written pièce(s) jointe(s) relue(s) " +
                    "pour $expected décodée(s) — écriture partielle",
            )
        }
        Log.i(
            TAG,
            "MMS reçu écrit : ${message["id"]}, fil $threadId, " +
                "$written pièce(s) jointe(s), texte ${body.length} car.",
        )

        // L'UI est peut-être ouverte — elle se met alors à jour d'elle-même —
        // mais c'est rarement le cas ici : l'app peut très bien ne pas tourner.
        // La notification, elle, part dans tous les cas.
        SmsEventBus.emitReceived(message)

        SmsNotifications.notifyIncoming(
            context = context,
            threadId = threadId,
            address = sender,
            body = body.ifEmpty { retrieved.subject.orEmpty() },
            timestamp = date,
        )
    }

    private fun smsManager(context: Context, subscriptionId: Int): SmsManager {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(SmsManager::class.java)
            return if (subscriptionId >= 0) {
                manager.createForSubscriptionId(subscriptionId)
            } else {
                manager
            }
        }
        @Suppress("DEPRECATION")
        return if (subscriptionId >= 0) {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        } else {
            SmsManager.getDefault()
        }
    }
}
