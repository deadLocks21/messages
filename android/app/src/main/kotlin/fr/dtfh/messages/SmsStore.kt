package fr.dtfh.messages

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager

/**
 * Accès au `ContentProvider` Telephony : c'est *le* store de l'application.
 *
 * Aucune base locale n'est tenue en parallèle — ce que voit l'utilisateur est
 * ce que contient `content://sms`, y compris ce qu'y écrivent d'autres apps.
 *
 * Les `Map` rendues ici sont directement le format du canal (cf.
 * `AndroidSmsChannel` côté Dart) : `date` en millisecondes, `direction` et
 * `status` en chaînes stables.
 */
class SmsStore(private val context: Context) {

    /**
     * Les MMS du stock. Les deux tables sont lues séparément puis fusionnées :
     * `content://sms` et `content://mms` n'ont ni les mêmes colonnes, ni la
     * même unité de date, ni la même façon de porter le corps du message.
     */
    private val mms = MmsStore(context)

    companion object {
        /** Action des accusés de dépôt réseau (`PendingIntent` de `sendTextMessage`). */
        const val ACTION_SMS_SENT = "fr.dtfh.messages.SMS_SENT"

        /** Action des accusés de remise. */
        const val ACTION_SMS_DELIVERED = "fr.dtfh.messages.SMS_DELIVERED"

        /** Identifiant (`_id`) du message concerné, porté par les deux actions. */
        const val EXTRA_MESSAGE_ID = "messageId"
        const val EXTRA_THREAD_ID = "threadId"

        /**
         * Clé de travail : le dernier MMS connu d'un fil pendant la fusion.
         * Retirée du résumé avant qu'il ne parte vers Dart.
         */
        private const val LAST_MMS_ID = "_lastMms"

        private val MESSAGE_PROJECTION = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.STATUS,
            Telephony.Sms.READ,
        )
    }

    private val resolver get() = context.contentResolver

    // ------------------------------------------------------------------ fils

    /**
     * Résumés des fils.
     *
     * Une passe sur `content://sms`, une sur `content://mms`, fusionnées par
     * `thread_id`. Plus simple et plus portable que
     * `content://mms-sms/conversations`, qui oblige à résoudre les
     * `recipient_ids` via la table des adresses canoniques.
     */
    fun listConversations(): List<Map<String, Any?>> = buildConversations(null)

    /**
     * Résumés des fils, éventuellement d'un seul ([onlyThreadId]).
     *
     * Deux passes de curseur — une par table — puis, seulement pour les fils
     * dont le dernier message est un MMS, la résolution de sa légende et de son
     * interlocuteur. C'est ce dernier point qui compte : recomposer chaque MMS
     * au passage coûterait deux requêtes et un descripteur de fichier *par
     * message*, sur le fil principal, à chaque événement du stock.
     */
    private fun buildConversations(onlyThreadId: String?): List<Map<String, Any?>> {
        val threads = LinkedHashMap<String, MutableMap<String, Any?>>()

        // Les MMS d'abord, en enveloppes seules : la fusion ne retient de toute
        // façon qu'un message par fil.
        for (summary in mms.listSummaries()) {
            if (onlyThreadId != null && summary.threadId != onlyThreadId) continue
            mergeMms(threads, summary)
        }

        query(
            Telephony.Sms.CONTENT_URI,
            MESSAGE_PROJECTION,
            onlyThreadId?.let { "${Telephony.Sms.THREAD_ID} = ?" },
            onlyThreadId?.let { arrayOf(it) },
            "${Telephony.Sms.DATE} DESC",
        ) { cursor ->
            while (cursor.moveToNext()) {
                val threadId = cursor.getString(Telephony.Sms.THREAD_ID) ?: continue
                val address = cursor.getString(Telephony.Sms.ADDRESS).orEmpty()
                val unread = cursor.getInt(Telephony.Sms.READ) == 0 &&
                    cursor.getInt(Telephony.Sms.TYPE) == Telephony.Sms.MESSAGE_TYPE_INBOX
                val date = cursor.getLong(Telephony.Sms.DATE)

                val existing = threads[threadId]
                if (existing == null) {
                    threads[threadId] = mutableMapOf(
                        "threadId" to threadId,
                        "recipients" to listOf(address),
                        "snippet" to cursor.getString(Telephony.Sms.BODY).orEmpty(),
                        "date" to date,
                        "messageCount" to 1,
                        "unreadCount" to if (unread) 1 else 0,
                        "lastAttachmentMimeType" to null,
                        LAST_MMS_ID to null,
                    )
                } else {
                    existing["messageCount"] = (existing["messageCount"] as Int) + 1
                    if (unread) existing["unreadCount"] = (existing["unreadCount"] as Int) + 1
                    // Le résumé n'appartient qu'au message le plus récent du
                    // fil — un SMS plus ancien ne doit pas reprendre la place
                    // d'un MMS qui vient d'arriver.
                    if (date > (existing["date"] as Long)) {
                        existing["date"] = date
                        existing["snippet"] =
                            cursor.getString(Telephony.Sms.BODY).orEmpty()
                        existing["lastAttachmentMimeType"] = null
                        existing[LAST_MMS_ID] = null
                        if (address.isNotEmpty()) existing["recipients"] = listOf(address)
                    }
                    // Le dernier message peut être sortant : dans ce cas son
                    // `address` est le destinataire, ce qui nomme quand même
                    // correctement le fil.
                    @Suppress("UNCHECKED_CAST")
                    val recipients = existing["recipients"] as List<String>
                    if (recipients.firstOrNull().isNullOrEmpty() && address.isNotEmpty()) {
                        existing["recipients"] = listOf(address)
                    }
                }
            }
        }

        for (thread in threads.values) resolveMmsSummary(thread)
        return threads.values.sortedByDescending { it["date"] as Long }
    }

    /**
     * Verse l'enveloppe d'un MMS dans le résumé de son fil.
     *
     * Le message retenu est mémorisé sous [LAST_MMS_ID] : sa légende et son
     * interlocuteur ne seront lus qu'à la fin, s'il est encore le dernier du
     * fil.
     */
    private fun mergeMms(
        threads: LinkedHashMap<String, MutableMap<String, Any?>>,
        summary: MmsStore.Summary,
    ) {
        val unread = !summary.read && summary.incoming

        val existing = threads[summary.threadId]
        if (existing == null) {
            threads[summary.threadId] = mutableMapOf(
                "threadId" to summary.threadId,
                "recipients" to listOf(""),
                "snippet" to "",
                "date" to summary.date,
                "messageCount" to 1,
                "unreadCount" to if (unread) 1 else 0,
                "lastAttachmentMimeType" to null,
                LAST_MMS_ID to summary,
            )
            return
        }

        existing["messageCount"] = (existing["messageCount"] as Int) + 1
        if (unread) existing["unreadCount"] = (existing["unreadCount"] as Int) + 1
        if (summary.date > (existing["date"] as Long)) {
            existing["date"] = summary.date
            existing[LAST_MMS_ID] = summary
        }
    }

    /**
     * Lit ce qu'il manque au fil dont le dernier message est un MMS : sa
     * légende, la nature de sa pièce jointe, son interlocuteur.
     *
     * Deux requêtes, mais seulement pour les fils concernés — jamais pour les
     * cent autres MMS enfouis dans l'historique.
     */
    private fun resolveMmsSummary(thread: MutableMap<String, Any?>) {
        val summary = thread.remove(LAST_MMS_ID) as? MmsStore.Summary ?: return
        val (snippet, attachmentMimeType) = mms.snippetOf(summary.id)
        thread["snippet"] = snippet
        thread["lastAttachmentMimeType"] = attachmentMimeType

        @Suppress("UNCHECKED_CAST")
        val recipients = thread["recipients"] as List<String>
        if (recipients.firstOrNull().isNullOrEmpty()) {
            val address = mms.addressFor(summary.id, summary.incoming)
            if (address.isNotEmpty()) thread["recipients"] = listOf(address)
        }
    }

    fun getConversation(threadId: String): Map<String, Any?>? =
        buildConversations(threadId).firstOrNull()

    /**
     * `thread_id` du jeu de destinataires, créé au besoin. C'est ce qui permet
     * d'ouvrir un fil vide avant tout envoi.
     */
    fun resolveThreadId(recipients: List<String>): String =
        Telephony.Threads.getOrCreateThreadId(context, recipients.toSet()).toString()

    /** Marque lus (et vus) tous les entrants du fil. */
    fun markThreadRead(threadId: String): Int {
        val values = ContentValues().apply {
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.SEEN, 1)
        }
        val smsUpdated = resolver.update(
            Telephony.Sms.CONTENT_URI,
            values,
            "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0",
            arrayOf(threadId),
        )
        return smsUpdated + mms.markThreadRead(threadId)
    }

    fun deleteThread(threadId: String): Int {
        // L'URI de conversation efface aussi les MMS du fil ; on retombe sur la
        // table SMS si le provider la refuse.
        val deleted = runCatching {
            resolver.delete(Uri.parse("content://mms-sms/conversations/$threadId"), null, null)
        }.getOrDefault(0)
        if (deleted > 0) return deleted
        return resolver.delete(
            Telephony.Sms.CONTENT_URI,
            "${Telephony.Sms.THREAD_ID} = ?",
            arrayOf(threadId),
        )
    }

    // -------------------------------------------------------------- messages

    fun listMessages(threadId: String, limit: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        messages.addAll(mms.listMessages(threadId, limit))
        query(
            Telephony.Sms.CONTENT_URI,
            MESSAGE_PROJECTION,
            "${Telephony.Sms.THREAD_ID} = ?",
            arrayOf(threadId),
            "${Telephony.Sms.DATE} DESC",
        ) { cursor ->
            while (cursor.moveToNext() && messages.size < limit) {
                messages.add(cursor.toMessage())
            }
        }
        // Le fil s'affiche du plus ancien au plus récent — SMS et MMS mêlés,
        // donc retriés : chaque table est ordonnée, leur concaténation non.
        return messages
            .sortedBy { it["date"] as Long }
            .takeLast(limit)
    }

    fun searchMessages(query: String, limit: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        messages.addAll(mms.searchMessages(query, limit))
        query(
            Telephony.Sms.CONTENT_URI,
            MESSAGE_PROJECTION,
            "${Telephony.Sms.BODY} LIKE ?",
            arrayOf("%$query%"),
            "${Telephony.Sms.DATE} DESC",
        ) { cursor ->
            while (cursor.moveToNext() && messages.size < limit) {
                messages.add(cursor.toMessage())
            }
        }
        return messages
            .sortedByDescending { it["date"] as Long }
            .take(limit)
    }

    fun getMessage(id: String): Map<String, Any?>? {
        if (MmsStore.isMmsId(id)) return mms.getMessage(id)
        var message: Map<String, Any?>? = null
        query(
            Telephony.Sms.CONTENT_URI,
            MESSAGE_PROJECTION,
            "${Telephony.Sms._ID} = ?",
            arrayOf(id),
            null,
        ) { cursor ->
            if (cursor.moveToFirst()) message = cursor.toMessage()
        }
        return message
    }

    fun deleteMessage(id: String): Int {
        if (MmsStore.isMmsId(id)) return mms.deleteMessage(id)
        return resolver.delete(
            ContentUris.withAppendedId(Telephony.Sms.CONTENT_URI, id.toLong()),
            null,
            null,
        )
    }

    // ----------------------------------------------------------------- envoi

    /**
     * Dépose un SMS et l'écrit immédiatement dans le stock, en `outbox`.
     *
     * Le message rendu est donc visible tout de suite, à l'état « Envoi… » ;
     * `SmsSendStatusReceiver` le fera passer à « Envoyé » puis « Distribué »
     * (ou « Non distribué ») via les `PendingIntent` posés ici.
     */
    fun sendMessage(
        recipients: List<String>,
        body: String,
        attachments: List<Map<String, Any?>>,
        subscriptionId: Int?,
    ): Map<String, Any?> {
        // Une pièce jointe change le transport de bout en bout : PDU vers le
        // MMSC et écriture dans `content://mms`. Rien de la voie SMS ci-dessous
        // ne s'y applique.
        if (attachments.isNotEmpty()) {
            return mms.sendMessage(recipients, body, attachments, subscriptionId)
        }
        val threadId = resolveThreadId(recipients)
        val address = recipients.first()
        val now = System.currentTimeMillis()

        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, address)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, now)
            put(Telephony.Sms.DATE_SENT, now)
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.SEEN, 1)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_OUTBOX)
            put(Telephony.Sms.THREAD_ID, threadId.toLong())
            if (subscriptionId != null) put(Telephony.Sms.SUBSCRIPTION_ID, subscriptionId)
        }
        val uri = resolver.insert(Telephony.Sms.CONTENT_URI, values)
            ?: throw IllegalStateException("insertion refusée par le provider")
        val messageId = uri.lastPathSegment ?: throw IllegalStateException("_id manquant")

        val manager = smsManager(subscriptionId)
        val parts = manager.divideMessage(body)
        // Un seul accusé suffit par message : seule la dernière partie porte les
        // PendingIntent, sinon un SMS long produirait autant d'événements que de
        // segments.
        val sent = ArrayList<PendingIntent?>(parts.size)
        val delivered = ArrayList<PendingIntent?>(parts.size)
        for (index in parts.indices) {
            val last = index == parts.size - 1
            sent.add(if (last) pendingIntent(ACTION_SMS_SENT, messageId, threadId) else null)
            delivered.add(
                if (last) pendingIntent(ACTION_SMS_DELIVERED, messageId, threadId) else null
            )
        }

        // Plusieurs destinataires ⇒ autant de SMS distincts : le SMS n'a pas de
        // notion de groupe, c'est le MMS qui l'apporte.
        for (recipient in recipients) {
            manager.sendMultipartTextMessage(recipient, null, parts, sent, delivered)
        }

        return getMessage(messageId) ?: mapOf(
            "id" to messageId,
            "threadId" to threadId,
            "address" to address,
            "body" to body,
            "date" to now,
            "direction" to "outgoing",
            "status" to "sending",
            "read" to true,
            "subscriptionId" to subscriptionId,
        )
    }

    /** Applique l'issue d'un envoi au stock, et rend l'état à publier. */
    fun applySendResult(messageId: String, delivered: Boolean, success: Boolean): String {
        if (MmsStore.isMmsId(messageId)) return mms.applySendResult(messageId, success)
        val values = ContentValues()
        val status = when {
            !success -> {
                values.put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_FAILED)
                values.put(Telephony.Sms.STATUS, Telephony.Sms.STATUS_FAILED)
                "failed"
            }
            delivered -> {
                values.put(Telephony.Sms.STATUS, Telephony.Sms.STATUS_COMPLETE)
                "delivered"
            }
            else -> {
                values.put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                "sent"
            }
        }
        resolver.update(
            ContentUris.withAppendedId(Telephony.Sms.CONTENT_URI, messageId.toLong()),
            values,
            null,
            null,
        )
        return status
    }

    /** Contenu d'une pièce jointe, pour sa vignette côté Dart. */
    fun readAttachment(partId: String): ByteArray? = mms.readPart(partId)

    /** Contenu d'un fichier désigné par une URI, pour l'aperçu d'un brouillon. */
    fun readUri(uri: String): ByteArray? = runCatching {
        resolver.openInputStream(Uri.parse(uri))?.use { it.readBytes() }
    }.getOrNull()

    /** Écrit un SMS entrant dans la boîte de réception. */
    fun insertIncoming(address: String, body: String, timestamp: Long): Map<String, Any?>? {
        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, address)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, timestamp)
            put(Telephony.Sms.DATE_SENT, timestamp)
            put(Telephony.Sms.READ, 0)
            put(Telephony.Sms.SEEN, 0)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
        }
        val uri = resolver.insert(Telephony.Sms.CONTENT_URI, values) ?: return null
        return getMessage(uri.lastPathSegment ?: return null)
    }

    @SuppressLint("NewApi")
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

    private fun pendingIntent(action: String, messageId: String, threadId: String): PendingIntent {
        val intent = Intent(action).apply {
            setPackage(context.packageName)
            putExtra(EXTRA_MESSAGE_ID, messageId)
            putExtra(EXTRA_THREAD_ID, threadId)
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

    private inline fun query(
        uri: Uri,
        projection: Array<String>,
        selection: String?,
        selectionArgs: Array<String>?,
        sortOrder: String?,
        block: (Cursor) -> Unit,
    ) {
        resolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use(block)
    }

    private fun Cursor.getString(column: String): String? =
        getColumnIndex(column).takeIf { it >= 0 }?.let { if (isNull(it)) null else getString(it) }

    private fun Cursor.getLong(column: String): Long =
        getColumnIndex(column).takeIf { it >= 0 }?.let { if (isNull(it)) 0L else getLong(it) } ?: 0L

    private fun Cursor.getInt(column: String): Int =
        getColumnIndex(column).takeIf { it >= 0 }?.let { if (isNull(it)) 0 else getInt(it) } ?: 0

    private fun Cursor.toMessage(): Map<String, Any?> {
        val type = getInt(Telephony.Sms.TYPE)
        val status = getInt(Telephony.Sms.STATUS)
        return mapOf(
            "id" to getLong(Telephony.Sms._ID).toString(),
            "threadId" to getLong(Telephony.Sms.THREAD_ID).toString(),
            "address" to getString(Telephony.Sms.ADDRESS).orEmpty(),
            "body" to getString(Telephony.Sms.BODY).orEmpty(),
            "date" to getLong(Telephony.Sms.DATE),
            "direction" to if (type == Telephony.Sms.MESSAGE_TYPE_INBOX) "incoming" else "outgoing",
            "status" to statusOf(type, status),
            "read" to (getInt(Telephony.Sms.READ) == 1),
            "subscriptionId" to getInt(Telephony.Sms.SUBSCRIPTION_ID),
            // Un SMS n'en a jamais : la clé est là pour que les deux tables
            // rendent la même forme au canal.
            "attachments" to emptyList<Map<String, Any?>>(),
        )
    }

    /**
     * Traduction des colonnes `type`/`status` du provider vers les états du
     * domaine. La colonne `status` ne vaut que pour les sortants et reste à
     * `STATUS_NONE` (-1) tant qu'aucun accusé de remise n'est revenu.
     */
    private fun statusOf(type: Int, status: Int): String = when (type) {
        Telephony.Sms.MESSAGE_TYPE_INBOX -> "received"
        Telephony.Sms.MESSAGE_TYPE_FAILED -> "failed"
        Telephony.Sms.MESSAGE_TYPE_OUTBOX, Telephony.Sms.MESSAGE_TYPE_QUEUED -> "sending"
        Telephony.Sms.MESSAGE_TYPE_SENT -> when (status) {
            Telephony.Sms.STATUS_COMPLETE -> "delivered"
            Telephony.Sms.STATUS_FAILED -> "failed"
            else -> "sent"
        }
        else -> "sending"
    }
}
