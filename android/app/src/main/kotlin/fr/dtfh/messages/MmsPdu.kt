package fr.dtfh.messages

import java.io.ByteArrayOutputStream

/**
 * Encodeur du PDU `M-Send.req` — le format sur le fil d'un MMS sortant.
 *
 * Android n'expose **aucune** API publique pour fabriquer ce PDU :
 * `SmsManager.sendMultimediaMessage` attend un fichier déjà encodé et se
 * contente de le pousser vers le MMSC. Les classes qui savent l'écrire
 * (`com.google.android.mms.pdu.PduComposer`) sont internes au framework. D'où
 * cet encodeur : le strict nécessaire des specs WAP-230 (WSP) et OMA MMS 1.2,
 * pas une implémentation générale.
 *
 * Le corps est un `multipart/related` : une partie SMIL de présentation
 * (attendue par les passerelles, même si les clients modernes l'ignorent), la
 * partie texte s'il y a une légende, puis une partie par pièce jointe.
 */
object MmsPdu {

    // En-têtes MMS (OMA-MMS-ENC, champs « assigned numbers »).
    private const val HEADER_MESSAGE_TYPE = 0x8C
    private const val HEADER_TRANSACTION_ID = 0x98
    private const val HEADER_MMS_VERSION = 0x8D
    private const val HEADER_FROM = 0x89
    private const val HEADER_TO = 0x97
    private const val HEADER_SUBJECT = 0x96
    private const val HEADER_MESSAGE_CLASS = 0x8A
    private const val HEADER_DELIVERY_REPORT = 0x86
    private const val HEADER_READ_REPORT = 0x90
    private const val HEADER_CONTENT_TYPE = 0x84

    private const val MESSAGE_TYPE_SEND_REQ = 0x80
    private const val MMS_VERSION_1_2 = 0x92
    private const val MESSAGE_CLASS_PERSONAL = 0x80
    private const val FROM_INSERT_ADDRESS_TOKEN = 0x81
    private const val NO = 0x81

    /** `application/vnd.wap.multipart.related`, valeur bien connue WSP. */
    private const val MULTIPART_RELATED = 0xB3

    /** Paramètres `type` et `start` du `multipart/related`. */
    private const val PARAM_TYPE = 0x89
    private const val PARAM_START = 0x8A

    /** En-têtes d'une partie. */
    private const val PART_CONTENT_LOCATION = 0x8E
    private const val PART_CONTENT_ID = 0xC0

    private const val CHARSET_UTF_8 = 0xEA // MIB 106, en short-integer

    private const val CONTENT_TYPE_SMIL = "application/smil"
    private const val CONTENT_TYPE_TEXT = "text/plain"
    private const val SMIL_CONTENT_ID = "<smil>"

    /**
     * Une partie du corps : son type, son nom de référence, son contenu.
     *
     * Classe ordinaire et non `data class` : l'égalité générée comparerait
     * [data] par référence, ce qui serait faux sans qu'on s'en aperçoive.
     */
    class Part(
        val contentType: String,
        val contentId: String,
        val contentLocation: String,
        val data: ByteArray,
    )

    /**
     * Encode le PDU complet.
     *
     * [transactionId] identifie l'échange auprès du MMSC ; il est repris dans
     * l'accusé (`M-Send.conf`), ce qui permettra plus tard d'apparier la
     * réponse au message. [text] est la légende, vide si le message n'en a pas.
     */
    fun compose(
        transactionId: String,
        recipients: List<String>,
        text: String,
        attachments: List<Part>,
    ): ByteArray {
        val out = ByteArrayOutputStream()

        out.writeHeaderByte(HEADER_MESSAGE_TYPE, MESSAGE_TYPE_SEND_REQ)
        out.write(HEADER_TRANSACTION_ID)
        out.writeTextString(transactionId)
        out.writeHeaderByte(HEADER_MMS_VERSION, MMS_VERSION_1_2)

        // L'adresse d'émission est laissée au réseau : le terminal ne connaît
        // pas toujours son propre MSISDN, et le MMSC la renseigne lui-même.
        out.write(HEADER_FROM)
        out.writeValueLength(1)
        out.write(FROM_INSERT_ADDRESS_TOKEN)

        for (recipient in recipients) {
            out.write(HEADER_TO)
            out.writeEncodedStringValue("${recipient.trim()}/TYPE=PLMN")
        }

        if (text.isNotEmpty()) {
            // Le sujet reprend le début de la légende : c'est ce qu'affichent
            // les terminaux qui ne savent pas rendre le corps.
            out.write(HEADER_SUBJECT)
            out.writeEncodedStringValue(text.take(40))
        }

        out.writeHeaderByte(HEADER_MESSAGE_CLASS, MESSAGE_CLASS_PERSONAL)
        out.writeHeaderByte(HEADER_DELIVERY_REPORT, NO)
        out.writeHeaderByte(HEADER_READ_REPORT, NO)

        val parts = buildParts(text, attachments)
        out.write(HEADER_CONTENT_TYPE)
        out.writeMultipartRelatedContentType()
        out.writeBody(parts)

        return out.toByteArray()
    }

    /**
     * Le corps, dans l'ordre attendu : la présentation d'abord (c'est elle que
     * désigne le paramètre `start`), puis le texte, puis les pièces jointes.
     */
    private fun buildParts(text: String, attachments: List<Part>): List<Part> {
        val parts = mutableListOf<Part>()
        val referenced = buildList {
            if (text.isNotEmpty()) add("text_0.txt")
            attachments.forEach { add(it.contentLocation) }
        }
        parts.add(
            Part(
                contentType = CONTENT_TYPE_SMIL,
                contentId = SMIL_CONTENT_ID,
                contentLocation = "smil.xml",
                data = smilFor(referenced, hasText = text.isNotEmpty())
                    .toByteArray(Charsets.UTF_8),
            )
        )
        if (text.isNotEmpty()) {
            parts.add(
                Part(
                    contentType = CONTENT_TYPE_TEXT,
                    contentId = "<text_0>",
                    contentLocation = "text_0.txt",
                    data = text.toByteArray(Charsets.UTF_8),
                )
            )
        }
        parts.addAll(attachments)
        return parts
    }

    /**
     * SMIL minimal : une diapositive, la région d'image et le texte. Les
     * passerelles qui l'exigent s'en contentent, celles qui l'ignorent n'en
     * souffrent pas.
     */
    private fun smilFor(locations: List<String>, hasText: Boolean): String {
        val media = buildString {
            for (location in locations) {
                val isText = hasText && location == "text_0.txt"
                val tag = if (isText) "text" else "img"
                val region = if (isText) "Text" else "Image"
                append("<$tag src=\"$location\" region=\"$region\"/>")
            }
        }
        return "<smil><head><layout>" +
            "<root-layout width=\"320px\" height=\"480px\"/>" +
            "<region id=\"Image\" top=\"0\" left=\"0\" " +
            "width=\"320px\" height=\"400px\" fit=\"meet\"/>" +
            "<region id=\"Text\" top=\"400px\" left=\"0\" " +
            "width=\"320px\" height=\"80px\"/>" +
            "</layout></head><body><par dur=\"5000ms\">$media</par></body></smil>"
    }

    // --------------------------------------------------------------- corps

    private fun ByteArrayOutputStream.writeBody(parts: List<Part>) {
        writeUintvar(parts.size.toLong())
        for (part in parts) {
            val headers = ByteArrayOutputStream().apply {
                writeContentType(part.contentType)
                write(PART_CONTENT_LOCATION)
                writeTextString(part.contentLocation)
                write(PART_CONTENT_ID)
                writeTextString(part.contentId)
            }.toByteArray()

            writeUintvar(headers.size.toLong())
            writeUintvar(part.data.size.toLong())
            write(headers)
            write(part.data)
        }
    }

    /**
     * Type d'une partie, en forme générale : longueur, type MIME en clair,
     * puis le jeu de caractères pour le texte — sans lui, une légende accentuée
     * arrive en mojibake sur le terminal d'en face.
     */
    private fun ByteArrayOutputStream.writeContentType(mimeType: String) {
        val value = ByteArrayOutputStream().apply {
            writeTextString(mimeType)
            if (mimeType.startsWith("text/")) {
                write(PARAM_CHARSET)
                write(CHARSET_UTF_8)
            }
        }.toByteArray()
        writeValueLength(value.size.toLong())
        write(value)
    }

    private const val PARAM_CHARSET = 0x81

    private fun ByteArrayOutputStream.writeMultipartRelatedContentType() {
        val value = ByteArrayOutputStream().apply {
            write(MULTIPART_RELATED)
            write(PARAM_TYPE)
            writeTextString(CONTENT_TYPE_SMIL)
            write(PARAM_START)
            writeTextString(SMIL_CONTENT_ID)
        }.toByteArray()
        writeValueLength(value.size.toLong())
        write(value)
    }

    // ------------------------------------------------- primitives WSP

    private fun ByteArrayOutputStream.writeHeaderByte(header: Int, value: Int) {
        write(header)
        write(value)
    }

    /**
     * Chaîne terminée par un zéro. Une valeur dont le premier octet dépasse
     * 127 serait prise pour un entier : la spec impose alors un guillemet de
     * tête.
     */
    private fun ByteArrayOutputStream.writeTextString(value: String) {
        val bytes = value.toByteArray(Charsets.UTF_8)
        if (bytes.isNotEmpty() && (bytes[0].toInt() and 0xFF) > 127) write(0x7F)
        write(bytes)
        write(0x00)
    }

    /** Chaîne précédée de sa longueur et de son jeu de caractères. */
    private fun ByteArrayOutputStream.writeEncodedStringValue(value: String) {
        val bytes = value.toByteArray(Charsets.UTF_8)
        // 1 octet de charset + la chaîne + son zéro final.
        writeValueLength((bytes.size + 2).toLong())
        write(CHARSET_UTF_8)
        write(bytes)
        write(0x00)
    }

    /**
     * Longueur : directement sur un octet jusqu'à 30, sinon un marqueur 0x1F
     * suivi d'un uintvar.
     */
    private fun ByteArrayOutputStream.writeValueLength(length: Long) {
        if (length < 31) {
            write(length.toInt())
        } else {
            write(0x1F)
            writeUintvar(length)
        }
    }

    /**
     * Entier à longueur variable, 7 bits utiles par octet, bit de poids fort à
     * 1 sur tous sauf le dernier.
     */
    private fun ByteArrayOutputStream.writeUintvar(value: Long) {
        var shift = 0
        var remaining = value
        while (remaining >= 0x80) {
            remaining = remaining shr 7
            shift += 7
        }
        remaining = value
        while (shift > 0) {
            write((((remaining shr shift) and 0x7F) or 0x80).toInt())
            shift -= 7
        }
        write((remaining and 0x7F).toInt())
    }
}
