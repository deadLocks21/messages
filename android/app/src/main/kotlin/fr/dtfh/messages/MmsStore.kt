package fr.dtfh.messages

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import androidx.core.content.FileProvider
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Accès à `content://mms` : le pendant de [SmsStore] pour les messages à
 * pièces jointes.
 *
 * Le MMS ne se lit pas comme un SMS. Là où une ligne de `content://sms` porte
 * tout le message, un MMS est éclaté en trois tables : l'enveloppe
 * (`content://mms`), les destinataires (`content://mms/<id>/addr`) et le
 * contenu (`content://mms/part`). Le texte lui-même est une *partie* comme une
 * autre. Reconstituer un message demande donc trois requêtes — d'où la lecture
 * en une passe par fil plutôt qu'une par message.
 *
 * Les identifiants rendus sont **préfixés** par [ID_PREFIX] : `_id` numérote
 * les deux tables indépendamment, et sans préfixe le message MMS 12 et le SMS
 * 12 seraient le même message aux yeux de l'app.
 */
class MmsStore(private val context: Context) {

    companion object {
        /** Ce qui distingue l'identifiant d'un MMS de celui d'un SMS. */
        const val ID_PREFIX = "mms:"

        /** Action de l'accusé de dépôt d'un MMS auprès du MMSC. */
        const val ACTION_MMS_SENT = "fr.dtfh.messages.MMS_SENT"

        /** L'app est-elle en train de parler d'un MMS ? */
        fun isMmsId(id: String) = id.startsWith(ID_PREFIX)

        fun rawId(id: String) = id.removePrefix(ID_PREFIX)

        /** `addr.type` : l'expéditeur d'un MMS reçu (PduHeaders.FROM). */
        private const val ADDRESS_TYPE_FROM = 137

        /** `addr.type` : un destinataire (PduHeaders.TO). */
        private const val ADDRESS_TYPE_TO = 151

        /** Adresse fictive que le provider pose pour « moi ». */
        private const val SELF_ADDRESS = "insert-address-token"

        private val MMS_PROJECTION = arrayOf(
            Telephony.Mms._ID,
            Telephony.Mms.THREAD_ID,
            Telephony.Mms.DATE,
            Telephony.Mms.MESSAGE_BOX,
            Telephony.Mms.READ,
            Telephony.Mms.SUBSCRIPTION_ID,
        )

        private val PART_PROJECTION = arrayOf(
            Telephony.Mms.Part._ID,
            Telephony.Mms.Part.CONTENT_TYPE,
            Telephony.Mms.Part.NAME,
            Telephony.Mms.Part.FILENAME,
            Telephony.Mms.Part.CONTENT_LOCATION,
            Telephony.Mms.Part.TEXT,
        )

        private val PART_URI: Uri = Uri.parse("content://mms/part")

        /**
         * URI d'une partie de MMS. Seul endroit qui la construit : le lecteur
         * audio ouvre exactement le même flux que la lecture des octets.
         */
        fun partUri(partId: String): Uri =
            ContentUris.withAppendedId(PART_URI, partId.toLong())

        /**
         * Durées déjà mesurées, par identifiant de partie.
         *
         * Le contenu d'une partie ne change jamais — son `_id` est celui d'un
         * fichier écrit une fois pour toutes — et la mesure coûte l'ouverture
         * d'un décodeur. Sans ce cache, rouvrir un fil de vingt vocaux les
         * remesurerait tous à chaque rafraîchissement, sur le fil qui sert les
         * lectures du stock.
         *
         * `-1` mémorise une mesure impossible : sans lui, un fichier illisible
         * serait retenté indéfiniment.
         */
        private val durations = ConcurrentHashMap<String, Int>()
    }

    private val resolver get() = context.contentResolver

    // -------------------------------------------------------------- lecture

    /** Tous les MMS d'un fil, du plus ancien au plus récent. */
    fun listMessages(threadId: String, limit: Int): List<Map<String, Any?>> =
        query("${Telephony.Mms.THREAD_ID} = ?", arrayOf(threadId), limit).reversed()

    /**
     * Enveloppes de tous les MMS, sans leur contenu.
     *
     * C'est ce que consomme la **liste des conversations**, et la raison d'être
     * de cette méthode : reconstituer un MMS complet coûte deux requêtes et un
     * descripteur de fichier par pièce jointe, alors que le résumé d'un fil ne
     * s'intéresse qu'à *un* message — le dernier. Les détails ne sont donc
     * résolus qu'après coup, par [snippetOf] et [addressOf], pour la poignée de
     * messages qui gagnent leur fil.
     *
     * Sans cette séparation, afficher la liste sur un stock ordinaire (une
     * centaine de MMS) demandait plusieurs centaines d'allers-retours au
     * provider, sur le fil principal, à chaque événement du stock — l'app
     * n'était plus utilisable.
     */
    fun listSummaries(limit: Int = 1000): List<Summary> {
        val summaries = mutableListOf<Summary>()
        resolver.query(
            Telephony.Mms.CONTENT_URI,
            MMS_PROJECTION,
            null,
            null,
            "${Telephony.Mms.DATE} DESC",
        )?.use { cursor ->
            while (cursor.moveToNext() && summaries.size < limit) {
                val box = cursor.getInt(cursor.getColumnIndexOrThrow(Telephony.Mms.MESSAGE_BOX))
                summaries.add(
                    Summary(
                        id = cursor.getLong(cursor.getColumnIndexOrThrow(Telephony.Mms._ID)),
                        threadId = cursor.getLong(
                            cursor.getColumnIndexOrThrow(Telephony.Mms.THREAD_ID)
                        ).toString(),
                        // Secondes côté MMS, millisecondes côté SMS.
                        date = cursor.getLong(
                            cursor.getColumnIndexOrThrow(Telephony.Mms.DATE)
                        ) * 1000L,
                        incoming = box == Telephony.Mms.MESSAGE_BOX_INBOX,
                        read = cursor.getInt(
                            cursor.getColumnIndexOrThrow(Telephony.Mms.READ)
                        ) == 1,
                    )
                )
            }
        }
        return summaries
    }

    /** L'enveloppe d'un MMS : ce qu'une seule passe de curseur peut donner. */
    class Summary(
        val id: Long,
        val threadId: String,
        val date: Long,
        val incoming: Boolean,
        val read: Boolean,
    )

    /**
     * Légende et nature du premier attachement d'un MMS, en **une** requête.
     *
     * Ni les tailles ni les octets : un résumé de fil n'en a que faire, et
     * mesurer une partie coûte l'ouverture d'un descripteur de fichier.
     */
    fun snippetOf(messageId: Long): Pair<String, String?> {
        val text = StringBuilder()
        var attachmentMimeType: String? = null
        resolver.query(
            PART_URI,
            arrayOf(Telephony.Mms.Part.CONTENT_TYPE, Telephony.Mms.Part.TEXT),
            "${Telephony.Mms.Part.MSG_ID} = ?",
            arrayOf(messageId.toString()),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val contentType = cursor.getString(0).orEmpty().lowercase()
                when {
                    contentType == "application/smil" -> Unit
                    contentType == "text/plain" -> {
                        val part = cursor.getString(1)
                        if (!part.isNullOrEmpty()) {
                            if (text.isNotEmpty()) text.append('\n')
                            text.append(part)
                        }
                    }
                    attachmentMimeType == null -> attachmentMimeType = contentType
                }
            }
        }
        return text.toString() to attachmentMimeType
    }

    /** L'interlocuteur d'un MMS. Une requête — à n'appeler qu'au besoin. */
    fun addressFor(messageId: Long, incoming: Boolean): String =
        addressOf(messageId, incoming)

    fun getMessage(id: String): Map<String, Any?>? =
        query("${Telephony.Mms._ID} = ?", arrayOf(rawId(id)), 1).firstOrNull()

    /**
     * Recherche dans le texte des MMS.
     *
     * Le texte étant une *partie*, la recherche part de `content://mms/part` et
     * remonte aux messages, à l'inverse de la recherche SMS.
     */
    fun searchMessages(needle: String, limit: Int): List<Map<String, Any?>> {
        val messageIds = LinkedHashSet<String>()
        resolver.query(
            PART_URI,
            arrayOf(Telephony.Mms.Part.MSG_ID),
            "${Telephony.Mms.Part.CONTENT_TYPE} = ? AND " +
                "${Telephony.Mms.Part.TEXT} LIKE ?",
            arrayOf("text/plain", "%$needle%"),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext() && messageIds.size < limit) {
                messageIds.add(cursor.getLong(0).toString())
            }
        }
        return messageIds.mapNotNull { getMessage(ID_PREFIX + it) }
    }

    fun deleteMessage(id: String): Int = resolver.delete(
        ContentUris.withAppendedId(Telephony.Mms.CONTENT_URI, rawId(id).toLong()),
        null,
        null,
    )

    /** Marque lus les MMS entrants du fil. */
    fun markThreadRead(threadId: String): Int {
        val values = ContentValues().apply {
            put(Telephony.Mms.READ, 1)
            put(Telephony.Mms.SEEN, 1)
        }
        return runCatching {
            resolver.update(
                Telephony.Mms.CONTENT_URI,
                values,
                "${Telephony.Mms.THREAD_ID} = ? AND ${Telephony.Mms.READ} = 0",
                arrayOf(threadId),
            )
        }.getOrDefault(0)
    }

    /** Contenu d'une partie, pour la vignette côté Dart. */
    fun readPart(partId: String): ByteArray? = runCatching {
        resolver.openInputStream(partUri(partId))?.use { it.readBytes() }
    }.getOrNull()

    private fun query(
        selection: String?,
        args: Array<String>?,
        limit: Int,
    ): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        resolver.query(
            Telephony.Mms.CONTENT_URI,
            MMS_PROJECTION,
            selection,
            args,
            "${Telephony.Mms.DATE} DESC",
        )?.use { cursor ->
            while (cursor.moveToNext() && messages.size < limit) {
                messages.add(cursor.toMessage())
            }
        }
        return messages
    }

    private fun Cursor.toMessage(): Map<String, Any?> {
        val id = getLong(getColumnIndexOrThrow(Telephony.Mms._ID))
        val box = getInt(getColumnIndexOrThrow(Telephony.Mms.MESSAGE_BOX))
        val incoming = box == Telephony.Mms.MESSAGE_BOX_INBOX
        val content = readParts(id)

        return mapOf(
            "id" to ID_PREFIX + id,
            "threadId" to
                getLong(getColumnIndexOrThrow(Telephony.Mms.THREAD_ID)).toString(),
            "address" to addressOf(id, incoming),
            "body" to content.text,
            // La date d'un MMS est en **secondes**, celle d'un SMS en
            // millisecondes : sans cette conversion, tous les MMS remonteraient
            // à 1970 et le fil serait dans le désordre.
            "date" to getLong(getColumnIndexOrThrow(Telephony.Mms.DATE)) * 1000L,
            "direction" to if (incoming) "incoming" else "outgoing",
            "status" to statusOf(box),
            "read" to (getInt(getColumnIndexOrThrow(Telephony.Mms.READ)) == 1),
            "subscriptionId" to
                getInt(getColumnIndexOrThrow(Telephony.Mms.SUBSCRIPTION_ID)),
            "attachments" to content.attachments,
        )
    }

    private fun statusOf(box: Int): String = when (box) {
        Telephony.Mms.MESSAGE_BOX_INBOX -> "received"
        Telephony.Mms.MESSAGE_BOX_SENT -> "sent"
        Telephony.Mms.MESSAGE_BOX_OUTBOX -> "sending"
        Telephony.Mms.MESSAGE_BOX_FAILED -> "failed"
        else -> "sending"
    }

    /**
     * L'interlocuteur : l'expéditeur pour un entrant, le premier destinataire
     * pour un sortant — la même convention que pour un SMS.
     */
    private fun addressOf(messageId: Long, incoming: Boolean): String {
        val uri = Uri.parse("content://mms/$messageId/addr")
        var fallback = ""
        resolver.query(
            uri,
            arrayOf(Telephony.Mms.Addr.ADDRESS, Telephony.Mms.Addr.TYPE),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val address = cursor.getString(0) ?: continue
                if (address == SELF_ADDRESS) continue
                val isFrom = cursor.getInt(1) == ADDRESS_TYPE_FROM
                if (isFrom == incoming) return address
                if (fallback.isEmpty()) fallback = address
            }
        }
        return fallback
    }

    private class Content(val text: String, val attachments: List<Map<String, Any?>>)

    /**
     * Découpe le contenu : le texte d'un côté, tout le reste de l'autre.
     *
     * La partie SMIL est écartée — c'est de la mise en page pour les terminaux
     * d'il y a vingt ans, pas une pièce jointe que l'utilisateur a envoyée.
     */
    private fun readParts(messageId: Long): Content {
        val text = StringBuilder()
        val attachments = mutableListOf<Map<String, Any?>>()

        resolver.query(
            PART_URI,
            PART_PROJECTION,
            "${Telephony.Mms.Part.MSG_ID} = ?",
            arrayOf(messageId.toString()),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val partId = cursor.getLong(0).toString()
                val contentType = cursor.getString(1).orEmpty().lowercase()
                when {
                    contentType == "application/smil" -> Unit
                    contentType == "text/plain" -> {
                        val part = cursor.getString(5) ?: readPartText(partId)
                        if (!part.isNullOrEmpty()) {
                            if (text.isNotEmpty()) text.append('\n')
                            text.append(part)
                        }
                    }
                    else -> attachments.add(
                        mapOf(
                            "id" to partId,
                            "mimeType" to contentType,
                            "fileName" to (cursor.getString(3)
                                ?: cursor.getString(2)
                                ?: cursor.getString(4)),
                            // Le poids n'est mesuré que pour ce qui l'affiche :
                            // une image se montre, un fichier s'annonce par son
                            // nom *et* sa taille. Mesurer coûte l'ouverture d'un
                            // descripteur — inutile pour une vignette.
                            "byteSize" to if (isVisual(contentType)) {
                                0
                            } else {
                                sizeOf(partId)
                            },
                            // Un vocal annonce sa longueur avant d'être joué —
                            // c'est ce qui décide de l'écouter ou non. Rien
                            // dans la table des parties ne la porte : elle se
                            // lit dans le fichier, une fois, puis se retient.
                            "durationMs" to if (contentType.startsWith("audio/")) {
                                durationOf(partId)
                            } else {
                                null
                            },
                        )
                    )
                }
            }
        }
        return Content(text.toString(), attachments)
    }

    /** Un texte trop long pour la colonne `text` vit dans un fichier à part. */
    private fun readPartText(partId: String): String? =
        readPart(partId)?.toString(Charsets.UTF_8)

    private fun isVisual(contentType: String): Boolean =
        contentType.startsWith("image/") || contentType.startsWith("video/")

    /** Durée d'une partie sonore, en millisecondes. Null si elle ne se lit pas. */
    private fun durationOf(partId: String): Int? {
        durations[partId]?.let { return if (it < 0) null else it }
        val retriever = MediaMetadataRetriever()
        val measured = runCatching {
            retriever.setDataSource(context, partUri(partId))
            retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toIntOrNull()
        }.getOrNull()
        // `close()` n'existe qu'à partir d'Android 10 ; `release()` partout.
        runCatching { retriever.release() }
        durations[partId] = measured ?: -1
        return measured
    }

    private fun sizeOf(partId: String): Int = runCatching {
        resolver.openFileDescriptor(
            ContentUris.withAppendedId(PART_URI, partId.toLong()),
            "r",
        )?.use { it.statSize.toInt() } ?: 0
    }.getOrDefault(0)

    // ---------------------------------------------------------------- envoi

    /**
     * Dépose un MMS : PDU vers le MMSC, et écriture immédiate dans le stock.
     *
     * L'ordre compte. Le message est d'abord écrit en `outbox` pour que le fil
     * l'affiche tout de suite — l'aller-retour avec le MMSC peut prendre
     * plusieurs secondes, et une bulle qui n'apparaît qu'à la fin donne
     * l'impression que l'envoi n'est pas parti.
     */
    fun sendMessage(
        recipients: List<String>,
        body: String,
        attachments: List<Map<String, Any?>>,
        subscriptionId: Int?,
    ): Map<String, Any?> {
        val threadId =
            Telephony.Threads.getOrCreateThreadId(context, recipients.toSet()).toString()
        val transactionId = "T${UUID.randomUUID().toString().replace("-", "").take(15)}"

        val parts = attachments.mapIndexed { index, attachment ->
            val uri = Uri.parse(attachment["uri"] as String)
            val mimeType = (attachment["mimeType"] as? String)
                ?: "application/octet-stream"
            val data = resolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw AttachmentUnavailableException()
            val name = (attachment["fileName"] as? String) ?: "part$index"
            MmsPdu.Part(
                contentType = mimeType,
                contentId = "<part$index>",
                contentLocation = name,
                data = data,
            )
        }

        val messageId = insertOutgoing(
            threadId = threadId,
            recipients = recipients,
            body = body,
            parts = parts,
            subscriptionId = subscriptionId,
            transactionId = transactionId,
        )

        val pdu = MmsPdu.compose(transactionId, recipients, body, parts)
        val pduUri = writePduFile(transactionId, pdu)

        smsManager(subscriptionId).sendMultimediaMessage(
            context,
            pduUri,
            null,
            null,
            SmsBridge.mmsSentIntent(context, ID_PREFIX + messageId, threadId),
        )

        return getMessage(ID_PREFIX + messageId) ?: mapOf(
            "id" to ID_PREFIX + messageId,
            "threadId" to threadId,
            "address" to recipients.first(),
            "body" to body,
            "date" to System.currentTimeMillis(),
            "direction" to "outgoing",
            "status" to "sending",
            "read" to true,
            "subscriptionId" to subscriptionId,
            "attachments" to emptyList<Map<String, Any?>>(),
        )
    }

    /** Écrit l'enveloppe, les destinataires et les parties du MMS sortant. */
    private fun insertOutgoing(
        threadId: String,
        recipients: List<String>,
        body: String,
        parts: List<MmsPdu.Part>,
        subscriptionId: Int?,
        transactionId: String,
    ): Long {
        val values = ContentValues().apply {
            put(Telephony.Mms.THREAD_ID, threadId.toLong())
            // Le provider attend des **secondes** ici, contrairement à la table
            // des SMS.
            put(Telephony.Mms.DATE, System.currentTimeMillis() / 1000)
            put(Telephony.Mms.MESSAGE_BOX, Telephony.Mms.MESSAGE_BOX_OUTBOX)
            put(Telephony.Mms.MESSAGE_TYPE, 128) // m-send-req
            put(Telephony.Mms.MMS_VERSION, 0x12)
            put(Telephony.Mms.READ, 1)
            put(Telephony.Mms.SEEN, 1)
            put(Telephony.Mms.TRANSACTION_ID, transactionId)
            put(Telephony.Mms.CONTENT_TYPE, "application/vnd.wap.multipart.related")
            if (subscriptionId != null) {
                put(Telephony.Mms.SUBSCRIPTION_ID, subscriptionId)
            }
        }
        val uri = resolver.insert(Telephony.Mms.CONTENT_URI, values)
            ?: throw IllegalStateException("insertion MMS refusée par le provider")
        val messageId = uri.lastPathSegment?.toLong()
            ?: throw IllegalStateException("_id manquant")

        insertAddress(messageId, SELF_ADDRESS, ADDRESS_TYPE_FROM)
        for (recipient in recipients) {
            insertAddress(messageId, recipient, ADDRESS_TYPE_TO)
        }

        if (body.isNotEmpty()) insertTextPart(messageId, body)
        for (part in parts) {
            if (part.contentType == "application/smil") continue
            if (part.contentType == "text/plain") continue
            insertDataPart(messageId, part)
        }
        return messageId
    }

    private fun insertAddress(messageId: Long, address: String, type: Int) {
        val values = ContentValues().apply {
            put(Telephony.Mms.Addr.ADDRESS, address)
            put(Telephony.Mms.Addr.TYPE, type)
            put(Telephony.Mms.Addr.CHARSET, 106) // UTF-8
        }
        runCatching {
            resolver.insert(Uri.parse("content://mms/$messageId/addr"), values)
        }
    }

    private fun insertTextPart(messageId: Long, text: String) {
        val values = ContentValues().apply {
            put(Telephony.Mms.Part.MSG_ID, messageId)
            put(Telephony.Mms.Part.CONTENT_TYPE, "text/plain")
            put(Telephony.Mms.Part.CHARSET, 106)
            put(Telephony.Mms.Part.CONTENT_ID, "<text_0>")
            put(Telephony.Mms.Part.CONTENT_LOCATION, "text_0.txt")
            put(Telephony.Mms.Part.TEXT, text)
        }
        runCatching { resolver.insert(partUriFor(messageId), values) }
    }

    /**
     * Une partie binaire s'insère en deux temps : la ligne d'abord, son contenu
     * ensuite par le flux que le provider ouvre pour elle. Écrire les octets
     * dans la colonne `_data` serait refusé — ce chemin appartient au provider.
     */
    private fun insertDataPart(messageId: Long, part: MmsPdu.Part) = insertDataPart(
        messageId = messageId,
        contentType = part.contentType,
        contentId = part.contentId,
        name = part.contentLocation,
        charset = null,
        data = part.data,
    )

    private fun insertDataPart(
        messageId: Long,
        contentType: String,
        contentId: String,
        name: String,
        charset: Int?,
        data: ByteArray,
    ) {
        val values = ContentValues().apply {
            put(Telephony.Mms.Part.MSG_ID, messageId)
            put(Telephony.Mms.Part.CONTENT_TYPE, contentType)
            put(Telephony.Mms.Part.CONTENT_ID, contentId)
            put(Telephony.Mms.Part.CONTENT_LOCATION, name)
            put(Telephony.Mms.Part.NAME, name)
            put(Telephony.Mms.Part.FILENAME, name)
            if (charset != null) put(Telephony.Mms.Part.CHARSET, charset)
        }
        val uri = runCatching {
            resolver.insert(partUriFor(messageId), values)
        }.getOrNull() ?: return
        runCatching {
            resolver.openOutputStream(uri)?.use { it.write(data) }
        }
    }

    // ------------------------------------------------------------ réception

    /**
     * Écrit un MMS **reçu** dans le stock, et rend le message tel que l'app le
     * lira — l'exact pendant de `SmsStore.insertIncoming`.
     *
     * Le fil est résolu par `Telephony.Threads.getOrCreateThreadId` sur la
     * seule adresse de l'expéditeur : c'est ce qui range le MMS dans la même
     * conversation que les SMS du même correspondant plutôt que dans un fil
     * jumeau.
     */
    fun insertIncoming(
        sender: String,
        retrieved: MmsPduReader.Retrieved,
        subscriptionId: Int?,
    ): Map<String, Any?>? {
        val threadId =
            Telephony.Threads.getOrCreateThreadId(context, setOf(sender)).toString()

        val values = ContentValues().apply {
            put(Telephony.Mms.THREAD_ID, threadId.toLong())
            // Secondes, comme partout dans ce provider.
            put(
                Telephony.Mms.DATE,
                (retrieved.dateMillis ?: System.currentTimeMillis()) / 1000,
            )
            put(Telephony.Mms.MESSAGE_BOX, Telephony.Mms.MESSAGE_BOX_INBOX)
            put(Telephony.Mms.MESSAGE_TYPE, 132) // m-retrieve-conf
            put(Telephony.Mms.MMS_VERSION, 0x12)
            put(Telephony.Mms.READ, 0)
            put(Telephony.Mms.SEEN, 0)
            put(Telephony.Mms.CONTENT_TYPE, "application/vnd.wap.multipart.related")
            retrieved.subject?.takeIf { it.isNotEmpty() }?.let {
                put(Telephony.Mms.SUBJECT, it)
                put(Telephony.Mms.SUBJECT_CHARSET, 106)
            }
            if (subscriptionId != null && subscriptionId >= 0) {
                put(Telephony.Mms.SUBSCRIPTION_ID, subscriptionId)
            }
        }
        val uri = runCatching {
            resolver.insert(Telephony.Mms.CONTENT_URI, values)
        }.getOrNull() ?: return null
        val messageId = uri.lastPathSegment?.toLongOrNull() ?: return null

        insertAddress(messageId, sender, ADDRESS_TYPE_FROM)
        insertAddress(messageId, SELF_ADDRESS, ADDRESS_TYPE_TO)

        var index = 0
        for (part in retrieved.parts) {
            // La partie SMIL est de la mise en page, pas une pièce jointe :
            // elle est écrite quand même — le stock est partagé avec les autres
            // apps — mais la lecture l'écarte déjà.
            if (part.isText && !part.isSmil) {
                insertTextPart(messageId, part.text())
            } else {
                insertDataPart(
                    messageId = messageId,
                    contentType = part.contentType,
                    contentId = "<part${index}>",
                    name = part.name ?: "part$index",
                    charset = part.charset,
                    data = part.data,
                )
            }
            index++
        }

        return getMessage(ID_PREFIX + messageId)
    }

    private fun partUriFor(messageId: Long): Uri =
        Uri.parse("content://mms/$messageId/part")

    /**
     * Le PDU part par un fichier : `sendMultimediaMessage` prend une URI, que
     * le service MMS du système ouvrira sous **son** identité. D'où le
     * `FileProvider` — un chemin de fichier direct lui serait inaccessible.
     */
    fun writePduFile(transactionId: String, pdu: ByteArray): Uri {
        val directory = File(context.cacheDir, "mms").apply { mkdirs() }
        sweepStale(directory)
        // Les photos prises, les images compressées et les GIF rapatriés
        // vivent au même endroit : un envoi est le bon moment pour faire le
        // ménage, puisqu'il prouve qu'une rédaction s'achève.
        sweepStale(File(context.cacheDir, "captures"))
        sweepStale(File(context.cacheDir, RemoteMedia.DIRECTORY))
        val file = File(directory, "$transactionId.pdu")
        file.writeBytes(pdu)
        return FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
    }

    /**
     * Le fichier où le **service MMS du système** déposera le PDU téléchargé.
     *
     * Même dossier et même `FileProvider` que [writePduFile], et pour la même
     * raison : le téléchargement s'exécute sous l'identité du service, pas sous
     * la nôtre. La différence est le sens de l'écriture — ici c'est lui qui
     * écrit, à nous de lui en accorder le droit (cf. `MmsReception`).
     */
    fun createDownloadFile(transactionId: String): Uri {
        val directory = File(context.cacheDir, "mms").apply { mkdirs() }
        sweepStale(directory)
        val file = File(directory, "$transactionId.download.pdu")
        file.delete()
        file.createNewFile()
        return FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
    }

    /** Relit ce que le service MMS a déposé, puis efface le fichier. */
    fun consumeDownloadFile(uri: Uri): ByteArray? {
        val bytes = runCatching {
            resolver.openInputStream(uri)?.use { it.readBytes() }
        }.getOrNull()
        runCatching { File(context.cacheDir, "mms/${uri.lastPathSegment}").delete() }
        return bytes?.takeIf { it.isNotEmpty() }
    }

    /**
     * Efface les fichiers temporaires trop vieux pour être encore utiles.
     *
     * Le seuil est large à dessein : une rédaction en cours peut durer, et
     * supprimer sous les pieds de l'utilisateur la photo qu'il vient de
     * joindre serait pire que quelques kilooctets gardés une journée de trop.
     */
    private fun sweepStale(directory: File) {
        val now = System.currentTimeMillis()
        directory.listFiles()?.forEach { file ->
            if (now - file.lastModified() > STALE_PDU_MS) file.delete()
        }
    }

    private fun smsManager(subscriptionId: Int?): SmsManager {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(SmsManager::class.java)
            return if (subscriptionId != null) {
                manager.createForSubscriptionId(subscriptionId)
            } else {
                manager
            }
        }
        @Suppress("DEPRECATION")
        return if (subscriptionId != null) {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        } else {
            SmsManager.getDefault()
        }
    }

    /** Applique l'issue d'un envoi MMS au stock, et rend l'état à publier. */
    fun applySendResult(messageId: String, success: Boolean): String {
        val values = ContentValues().apply {
            put(
                Telephony.Mms.MESSAGE_BOX,
                if (success) {
                    Telephony.Mms.MESSAGE_BOX_SENT
                } else {
                    Telephony.Mms.MESSAGE_BOX_FAILED
                },
            )
        }
        runCatching {
            resolver.update(
                ContentUris.withAppendedId(
                    Telephony.Mms.CONTENT_URI,
                    rawId(messageId).toLong(),
                ),
                values,
                null,
                null,
            )
        }
        return if (success) "sent" else "failed"
    }
}

private const val STALE_PDU_MS = 24 * 60 * 60 * 1000L

class AttachmentUnavailableException :
    IllegalStateException("Pièce jointe illisible")
