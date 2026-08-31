package fr.dtfh.messages

/**
 * Décodeur des PDU MMS entrants — le **miroir** de [MmsPdu].
 *
 * Même raison d'être que l'encodeur : Android n'expose aucune API publique pour
 * lire ces PDU (`com.google.android.mms.pdu.PduParser` est interne au
 * framework), et le projet a fait le choix d'écrire le format à la main plutôt
 * que d'embarquer une bibliothèque MMS. Les primitives WSP sont donc les mêmes
 * qu'à l'encodage, prises à l'envers : uintvar, value-length, text-string,
 * encoded-string-value, puis le même découpage du corps `multipart/related`.
 *
 * Deux PDU nous intéressent :
 * - `M-Notification.ind`, ce que `WAP_PUSH_DELIVER` dépose : pas le message,
 *   mais l'adresse où le récupérer ([Notification]) ;
 * - `M-Retrieve.conf`, ce que le MMSC rend au téléchargement : le message
 *   lui-même ([Retrieved]).
 *
 * **Ces octets viennent du réseau.** Rien n'y est présumé correct : toute
 * longueur aberrante, tout en-tête tronqué, toute partie qui déborde du tampon
 * se solde par un `null` rendu à l'appelant. Un décodeur qui laisserait filer
 * une exception ferait tomber un `BroadcastReceiver`, donc l'app, sur un PDU
 * malformé — le réseau n'a pas à pouvoir faire ça.
 */
object MmsPduReader {

    // En-têtes d'un **message** (OMA-MMS-ENC). À ne pas confondre avec ceux
    // d'une partie, plus bas : les deux tables numérotent indépendamment, et
    // 0x8E vaut ici « taille du message » là où il vaut « Content-Location »
    // dans une partie. Un décodeur qui les mélange lit du bruit.
    private const val HEADER_CONTENT_LOCATION = 0x83
    private const val HEADER_CONTENT_TYPE = 0x84
    private const val HEADER_DATE = 0x85
    private const val HEADER_FROM = 0x89
    private const val HEADER_MESSAGE_TYPE = 0x8C
    private const val HEADER_MESSAGE_SIZE = 0x8E
    private const val HEADER_SUBJECT = 0x96
    private const val HEADER_TRANSACTION_ID = 0x98

    /** En-têtes d'une **partie** (table des en-têtes WSP). */
    private const val PART_CONTENT_LOCATION = 0x8E
    private const val PART_CONTENT_ID = 0xC0
    private const val PART_CONTENT_DISPOSITION = 0xC5
    private const val PART_CONTENT_DISPOSITION_OLD = 0xAE

    /** Paramètres d'un type de contenu. */
    private const val PARAM_CHARSET = 0x81
    private const val PARAM_NAME = 0x85
    private const val PARAM_FILENAME = 0x86
    private const val PARAM_NAME_TEXT = 0x97
    private const val PARAM_FILENAME_TEXT = 0x98

    /** `X-Mms-Message-Type` : la notification de dépôt, et le message rendu. */
    const val MESSAGE_TYPE_NOTIFICATION_IND = 0x82
    const val MESSAGE_TYPE_RETRIEVE_CONF = 0x84

    /** Le `From` peut être une adresse, ou le jeton « c'est au réseau de dire ». */
    private const val ADDRESS_PRESENT_TOKEN = 0x80

    /**
     * Garde-fou sur les longueurs annoncées. Aucun MMS légitime n'approche ces
     * ordres de grandeur ; au-delà, l'annonce ment et on abandonne plutôt que
     * d'allouer.
     */
    private const val MAX_PARTS = 256
    private const val MAX_HEADERS_BYTES = 64 * 1024

    /** Ce que porte un `M-Notification.ind` : de quoi aller chercher le reste. */
    class Notification(
        val contentLocation: String,
        val transactionId: String?,
        val from: String?,
        val messageSize: Long,
    )

    /** Un `M-Retrieve.conf` décodé : le message tel qu'il sera écrit au stock. */
    class Retrieved(
        val from: String?,
        /** En millisecondes — le PDU la porte en secondes, comme le provider. */
        val dateMillis: Long?,
        val subject: String?,
        val parts: List<Part>,
    )

    /**
     * Une partie du corps. Le pendant de [MmsPdu.Part], à ceci près qu'elle
     * porte en plus le **jeu de caractères** : sans lui, un texte en
     * ISO-8859-1 ou en UCS-2 relu en UTF-8 arrive en mojibake.
     */
    class Part(
        val contentType: String,
        val name: String?,
        val charset: Int?,
        val data: ByteArray,
    ) {
        val isSmil: Boolean get() = contentType.equals("application/smil", ignoreCase = true)

        val isText: Boolean get() = contentType.equals("text/plain", ignoreCase = true)

        /** Le texte de la partie, dans le jeu de caractères qu'elle annonce. */
        fun text(): String = runCatching {
            data.toString(MmsCharsets.of(charset))
        }.getOrDefault(String(data, Charsets.UTF_8))
    }

    // ------------------------------------------------------------ entrées

    /** Décode une notification de dépôt. `null` si elle est inexploitable. */
    fun readNotification(pdu: ByteArray): Notification? = runCatching {
        val reader = Reader(pdu)
        val headers = reader.readMessageHeaders() ?: return null
        val location = headers.contentLocation ?: return null
        Notification(
            contentLocation = location,
            transactionId = headers.transactionId,
            from = headers.from,
            messageSize = headers.messageSize ?: 0L,
        )
    }.getOrNull()

    /** Décode un message rapatrié. `null` s'il ne tient pas debout. */
    fun readRetrieveConf(pdu: ByteArray): Retrieved? = runCatching {
        val reader = Reader(pdu)
        val headers = reader.readMessageHeaders() ?: return null
        // `X-Mms-Message-Type` est le premier en-tête de tout PDU MMS : son
        // absence signifie qu'on ne lit pas un MMS du tout, et non un message
        // sans contenu.
        if (headers.messageType == null) return null
        // Un corps absent n'est pas une erreur de décodage : certains MMS ne
        // portent qu'un sujet. Une liste vide est une réponse valable.
        val parts = if (headers.hasBody) reader.readBody() else emptyList()
        Retrieved(
            from = headers.from,
            dateMillis = headers.date?.times(1000L),
            subject = headers.subject,
            parts = parts ?: return null,
        )
    }.getOrNull()

    // ------------------------------------------------------------- en-têtes

    private class MessageHeaders {
        var messageType: Int? = null
        var transactionId: String? = null
        var contentLocation: String? = null
        var from: String? = null
        var subject: String? = null
        var date: Long? = null
        var messageSize: Long? = null
        var hasBody = false
    }

    /**
     * Le lecteur : une position dans un tableau d'octets, et rien d'autre.
     *
     * Toute lecture au-delà de la fin lève [Truncated], attrapée en haut par
     * les deux points d'entrée — c'est ce qui transforme un PDU tronqué en
     * abandon propre plutôt qu'en plantage.
     */
    private class Reader(private val bytes: ByteArray) {
        var position = 0

        private class Truncated : RuntimeException("PDU tronqué")

        val remaining: Int get() = bytes.size - position

        fun byte(): Int {
            if (position >= bytes.size) throw Truncated()
            return bytes[position++].toInt() and 0xFF
        }

        fun peek(): Int {
            if (position >= bytes.size) throw Truncated()
            return bytes[position].toInt() and 0xFF
        }

        fun bytes(count: Int): ByteArray {
            if (count < 0 || count > remaining) throw Truncated()
            val slice = bytes.copyOfRange(position, position + count)
            position += count
            return slice
        }

        fun skip(count: Int) {
            if (count < 0 || count > remaining) throw Truncated()
            position += count
        }

        /** Entier à longueur variable : 7 bits utiles, bit de poids fort = suite. */
        fun uintvar(): Long {
            var value = 0L
            var read = 0
            while (true) {
                val b = byte()
                value = (value shl 7) or (b and 0x7F).toLong()
                // Cinq octets suffisent à 32 bits ; au-delà, la valeur ment.
                if (++read > 5) throw Truncated()
                if (b and 0x80 == 0) return value
            }
        }

        /** Longueur : un octet jusqu'à 30, sinon le marqueur 0x1F et un uintvar. */
        fun valueLength(): Long {
            val first = byte()
            return if (first < 31) first.toLong() else uintvar()
        }

        /** Entier sur 1 à 30 octets, poids fort en tête. */
        fun longInteger(): Long {
            val length = byte()
            if (length > 30) throw Truncated()
            var value = 0L
            repeat(length) { value = (value shl 8) or byte().toLong() }
            return value
        }

        /** Entier court (bit de poids fort à 1) ou long-integer. */
        fun integer(): Long {
            val first = peek()
            return if (first >= 0x80) (byte() and 0x7F).toLong() else longInteger()
        }

        /** Chaîne terminée par un zéro, guillemet de tête retiré s'il y est. */
        fun textString(): String {
            val start = position
            while (byte() != 0x00) Unit
            var from = start
            // 0x7F protège une valeur qui commencerait au-delà de 127 ; 0x22
            // (guillemet) précède les chaînes citées. Ni l'un ni l'autre ne
            // fait partie de la valeur.
            if (position - 1 > from) {
                val first = bytes[from].toInt() and 0xFF
                if (first == 0x7F || first == 0x22) from++
            }
            return String(bytes, from, position - 1 - from, Charsets.UTF_8)
        }

        /**
         * Chaîne précédée de sa longueur et de son jeu de caractères — ou
         * simple text-string quand l'émetteur s'en dispense, ce que la spec
         * autorise et que les MMSC pratiquent.
         */
        fun encodedStringValue(): String {
            if (peek() >= 0x20) return textString()
            val length = valueLength().toInt()
            if (length < 0 || length > remaining) throw Truncated()
            val end = position + length
            val charset = integer().toInt()
            val raw = bytes(end - position)
            // Le zéro final compte dans la longueur annoncée.
            val trimmed = if (raw.isNotEmpty() && raw.last() == 0.toByte()) {
                raw.copyOfRange(0, raw.size - 1)
            } else {
                raw
            }
            return runCatching { trimmed.toString(MmsCharsets.of(charset)) }
                .getOrDefault(String(trimmed, Charsets.UTF_8))
        }

        /**
         * Passe une valeur d'en-tête dont on ne sait rien.
         *
         * Sauter à l'aveugle est le seul moyen d'atteindre les en-têtes qui
         * suivent : la table des champs MMS est bien plus longue que ce qu'on
         * lit, et un émetteur peut poser n'importe lequel. La forme se déduit
         * du premier octet, comme le veut WSP.
         */
        fun skipUnknownValue() {
            val first = peek()
            when {
                first < 0x1F -> {
                    // Longueur courte : l'octet lu est le compte des suivants.
                    skip(byte())
                }
                first == 0x1F -> {
                    byte()
                    val length = uintvar()
                    if (length > remaining) throw Truncated()
                    skip(length.toInt())
                }
                first >= 0x80 -> byte()
                else -> textString()
            }
        }

        /**
         * Les en-têtes du message, jusqu'au `Content-Type` — qui, par la spec,
         * est le dernier : le corps commence juste derrière.
         */
        fun readMessageHeaders(): MessageHeaders? {
            val headers = MessageHeaders()
            while (remaining > 0) {
                val field = byte()
                // Un en-tête commence toujours par un numéro de champ bien
                // connu. Autre chose signifie qu'on a perdu l'alignement.
                if (field < 0x80) return null
                when (field) {
                    HEADER_MESSAGE_TYPE -> headers.messageType = byte()
                    HEADER_TRANSACTION_ID -> headers.transactionId = textString()
                    HEADER_CONTENT_LOCATION -> headers.contentLocation = textString()
                    HEADER_SUBJECT -> headers.subject = encodedStringValue()
                    HEADER_MESSAGE_SIZE -> headers.messageSize = longInteger()
                    HEADER_DATE -> headers.date = longInteger()
                    HEADER_FROM -> headers.from = readFrom()
                    HEADER_CONTENT_TYPE -> {
                        readContentType()
                        headers.hasBody = true
                        return headers
                    }
                    else -> skipUnknownValue()
                }
            }
            return headers
        }

        /**
         * `From` : une longueur, puis soit le jeton « adresse présente » suivi
         * de l'adresse, soit le jeton « à insérer par le réseau » — c'est ce
         * dernier que [MmsPdu] écrit à l'émission, et il ne nomme personne.
         */
        private fun readFrom(): String? {
            val length = valueLength().toInt()
            if (length < 1 || length > remaining) throw Truncated()
            val end = position + length
            val token = byte()
            val address = if (token == ADDRESS_PRESENT_TOKEN && position < end) {
                encodedStringValue()
            } else {
                null
            }
            position = end
            return address?.let(::stripAddressType)
        }

        /**
         * Type de contenu du **message** : lu pour ses paramètres, jetés
         * ensuite. Seule sa longueur compte vraiment — c'est elle qui place le
         * début du corps.
         */
        private fun readContentType() {
            val length = valueLength().toInt()
            if (length < 0 || length > remaining) throw Truncated()
            position += length
        }

        // --------------------------------------------------------- corps

        /**
         * Le corps, exactement dans la forme que produit `MmsPdu.writeBody` :
         * le nombre de parties en uintvar, puis pour chacune la longueur de ses
         * en-têtes, celle de ses données, les en-têtes, les données.
         */
        fun readBody(): List<Part>? {
            if (remaining == 0) return emptyList()
            val count = uintvar()
            if (count < 0 || count > MAX_PARTS) return null
            val parts = mutableListOf<Part>()
            repeat(count.toInt()) {
                val headersLength = uintvar()
                val dataLength = uintvar()
                if (headersLength > MAX_HEADERS_BYTES) throw Truncated()
                if (dataLength > remaining - headersLength) throw Truncated()
                val headerBytes = bytes(headersLength.toInt())
                val data = bytes(dataLength.toInt())
                parts.add(readPart(headerBytes, data))
            }
            return parts
        }

        /**
         * Les en-têtes d'une partie : son type de contenu d'abord (la spec
         * l'impose en tête), puis les champs qui la nomment.
         */
        private fun readPart(headerBytes: ByteArray, data: ByteArray): Part {
            val headers = Reader(headerBytes)
            var contentType = "application/octet-stream"
            var charset: Int? = null
            var name: String? = null
            var contentId: String? = null
            var location: String? = null

            runCatching {
                val typed = headers.readPartContentType()
                contentType = typed.first
                charset = typed.second
                name = typed.third
                while (headers.remaining > 0) {
                    when (val field = headers.byte()) {
                        PART_CONTENT_LOCATION -> location = headers.textString()
                        PART_CONTENT_ID -> contentId = headers.textString()
                        PART_CONTENT_DISPOSITION,
                        PART_CONTENT_DISPOSITION_OLD,
                        -> name = headers.readDispositionFilename() ?: name
                        else -> if (field < 0x80) return@runCatching else headers.skipUnknownValue()
                    }
                }
            }

            // Un nom explicite d'abord, puis ce qui en tient lieu. Le
            // Content-ID est un dernier recours : il est souvent `<0>`, ce qui
            // ne dit rien, mais vaut mieux qu'une pièce jointe anonyme.
            val label = name ?: location ?: contentId?.trim('<', '>')?.takeIf { it.isNotEmpty() }
            return Part(contentType, label, charset, data)
        }

        /**
         * Type d'une partie : longueur, puis le type — **en entier court**
         * (valeur bien connue WSP) **ou en clair**, les deux se rencontrent —
         * puis ses paramètres, dont le jeu de caractères et le nom.
         */
        private fun readPartContentType(): Triple<String, Int?, String?> {
            val length = valueLength().toInt()
            if (length < 0 || length > remaining) return Triple(
                "application/octet-stream", null, null,
            )
            val end = position + length
            val first = peek()
            val type = if (first >= 0x80) {
                MmsContentTypes.of(byte() and 0x7F)
            } else {
                textString()
            }
            var charset: Int? = null
            var name: String? = null
            while (position < end) {
                when (byte()) {
                    PARAM_CHARSET -> charset = integer().toInt()
                    PARAM_NAME, PARAM_FILENAME -> name = textString()
                    PARAM_NAME_TEXT, PARAM_FILENAME_TEXT -> name = encodedStringValue()
                    else -> {
                        // Paramètre inconnu : on ne sait pas le lire, mais on
                        // sait où s'arrête la valeur — inutile d'insister.
                        position = end
                    }
                }
            }
            position = end
            return Triple(type, charset, name)
        }

        /** `Content-Disposition` : seul son paramètre `filename` nous intéresse. */
        private fun readDispositionFilename(): String? {
            val length = valueLength().toInt()
            if (length < 1 || length > remaining) throw Truncated()
            val end = position + length
            var filename: String? = null
            byte() // le jeton de disposition (attachment, inline…)
            while (position < end) {
                when (byte()) {
                    PARAM_NAME, PARAM_FILENAME -> filename = textString()
                    PARAM_NAME_TEXT, PARAM_FILENAME_TEXT -> filename = encodedStringValue()
                    else -> position = end
                }
            }
            position = end
            return filename
        }
    }

    /**
     * `+33612345678/TYPE=PLMN` désigne le même correspondant que
     * `+33612345678` : le suffixe dit le plan de numérotation, pas l'adresse.
     * Le garder ferait deux fils pour une personne.
     */
    fun stripAddressType(address: String): String =
        address.substringBefore("/TYPE=").trim()
}

/** Jeux de caractères, du numéro MIB au décodeur de la JVM. */
internal object MmsCharsets {
    fun of(mib: Int?): java.nio.charset.Charset = when (mib) {
        null, 0 -> Charsets.UTF_8
        3 -> Charsets.US_ASCII
        4 -> Charsets.ISO_8859_1
        106 -> Charsets.UTF_8
        1000 -> Charsets.UTF_16 // ISO-10646-UCS-2
        1013 -> Charsets.UTF_16BE
        1014 -> Charsets.UTF_16LE
        1015 -> Charsets.UTF_16
        else -> Charsets.UTF_8
    }
}

/**
 * Types de contenu bien connus de WSP (WAP-230, « Assigned Numbers »).
 *
 * Un émetteur a le choix : écrire `image/jpeg` en clair, ou poser l'entier
 * court 0x1E qui le désigne. Les deux se rencontrent sur le terrain — d'où
 * cette table, sans laquelle une photo arriverait en `application/octet-stream`
 * et ne s'afficherait pas.
 */
internal object MmsContentTypes {
    private val TABLE = arrayOf(
        "*/*", "text/*", "text/html", "text/plain", "text/x-hdml",
        "text/x-ttml", "text/x-vCalendar", "text/x-vCard", "text/vnd.wap.wml",
        "text/vnd.wap.wmlscript", "text/vnd.wap.wta-event", "multipart/*",
        "multipart/mixed", "multipart/form-data", "multipart/byteranges",
        "multipart/alternative", "application/*", "application/java-vm",
        "application/x-www-form-urlencoded", "application/x-hdmlc",
        "application/vnd.wap.wmlc", "application/vnd.wap.wmlscriptc",
        "application/vnd.wap.wta-eventc", "application/vnd.wap.uaprof",
        "application/vnd.wap.wtls-ca-certificate",
        "application/vnd.wap.wtls-user-certificate",
        "application/x-x509-ca-cert", "application/x-x509-user-cert",
        "image/*", "image/gif", "image/jpeg", "image/tiff", "image/png",
        "image/vnd.wap.wbmp", "application/vnd.wap.multipart.*",
        "application/vnd.wap.multipart.mixed",
        "application/vnd.wap.multipart.form-data",
        "application/vnd.wap.multipart.byteranges",
        "application/vnd.wap.multipart.alternative", "application/xml",
        "text/xml", "application/vnd.wap.wbxml",
        "application/x-x968-cross-cert", "application/x-x968-ca-cert",
        "application/x-x968-user-cert", "text/vnd.wap.si",
        "application/vnd.wap.sic", "text/vnd.wap.sl",
        "application/vnd.wap.slc", "text/vnd.wap.co",
        "application/vnd.wap.coc", "application/vnd.wap.multipart.related",
        "application/vnd.wap.sia", "text/vnd.wap.connectivity-xml",
        "application/vnd.wap.connectivity-wbxml",
        "application/pkcs7-signature", "application/vnd.wap.hashed-certificate",
        "application/vnd.wap.signed-certificate",
        "application/vnd.wap.cert-response", "application/xhtml+xml",
        "application/wml+xml", "text/css", "application/vnd.wap.mms-message",
        "application/vnd.wap.rollover-certificate",
        "application/vnd.wap.locc+wbxml", "application/vnd.wap.loc+xml",
        "application/vnd.syncml.dm+wbxml", "application/vnd.syncml.dm+xml",
        "application/vnd.syncml.notification",
        "application/vnd.wap.xhtml+xml", "application/vnd.wv.csp.cir",
        "application/vnd.oma.dd+xml", "application/vnd.oma.drm.message",
        "application/vnd.oma.drm.content", "application/vnd.oma.drm.rights+xml",
        "application/vnd.oma.drm.rights+wbxml", "application/vnd.wv.csp+xml",
        "application/vnd.wv.csp+wbxml",
        "application/vnd.syncml.ds.notification", "audio/*", "video/*",
        "application/vnd.oma.dd2+xml", "application/mikey",
        "application/vnd.oma.dcd", "application/vnd.oma.dcdc",
    )

    fun of(value: Int): String =
        TABLE.getOrElse(value) { "application/octet-stream" }
}
