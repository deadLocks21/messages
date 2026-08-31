package fr.dtfh.messages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream

/**
 * Tests du décodeur de PDU MMS.
 *
 * Le test qui vaut le plus est l'**aller-retour** : encoder un message avec
 * [MmsPdu], le relire avec [MmsPduReader], et retrouver exactement les mêmes
 * parties. Les deux moitiés étant écrites à la main faute d'API publique, c'est
 * la seule façon de prouver qu'elles parlent bien du même format — et une
 * dérive de l'une sera signalée par l'autre.
 *
 * Les cas tordus, eux, sont construits octet par octet : ce sont précisément
 * ceux que notre encodeur ne produit pas, mais qu'un MMSC ou un terminal d'en
 * face nous enverra.
 */
class MmsPduReaderTest {

    // ------------------------------------------------------------ aller-retour

    @Test
    fun `un message encode puis relu rend les memes parties`() {
        val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0x01, 0x02, 0x03)
        val pdu = MmsPdu.compose(
            transactionId = "T0123456789",
            recipients = listOf("+33612345678"),
            text = "Bonjour",
            attachments = listOf(
                MmsPdu.Part("image/jpeg", "<part0>", "photo.jpg", jpeg),
            ),
        )

        val retrieved = MmsPduReader.readRetrieveConf(pdu)
        assertNotNull(retrieved)
        val parts = retrieved!!.parts

        // SMIL de présentation, texte, pièce jointe — dans cet ordre.
        assertEquals(3, parts.size)
        assertTrue(parts[0].isSmil)

        assertTrue(parts[1].isText)
        assertEquals("Bonjour", parts[1].text())

        assertEquals("image/jpeg", parts[2].contentType)
        assertEquals("photo.jpg", parts[2].name)
        assertTrue(jpeg.contentEquals(parts[2].data))
    }

    @Test
    fun `un texte accentue survit a l'aller-retour`() {
        val pdu = MmsPdu.compose(
            transactionId = "T1",
            recipients = listOf("+33600000000"),
            text = "Déjà vu — çà et là, où ?",
            attachments = emptyList(),
        )

        val parts = MmsPduReader.readRetrieveConf(pdu)!!.parts
        val text = parts.single { it.isText }
        assertEquals("Déjà vu — çà et là, où ?", text.text())
        // Le charset annoncé est celui qu'on écrira dans la colonne CHARSET.
        assertEquals(106, text.charset)
    }

    @Test
    fun `un message sans legende n'a pas de partie texte`() {
        val pdu = MmsPdu.compose(
            transactionId = "T2",
            recipients = listOf("+33600000000"),
            text = "",
            attachments = listOf(
                MmsPdu.Part("image/gif", "<part0>", "chat.gif", byteArrayOf(1, 2)),
            ),
        )

        val parts = MmsPduReader.readRetrieveConf(pdu)!!.parts
        assertEquals(2, parts.size)
        assertTrue(parts.none { it.isText })
        assertEquals("image/gif", parts[1].contentType)
    }

    @Test
    fun `plusieurs pieces jointes gardent leur ordre et leurs octets`() {
        val attachments = (0 until 4).map { index ->
            MmsPdu.Part(
                contentType = "application/pdf",
                contentId = "<part$index>",
                contentLocation = "doc$index.pdf",
                data = ByteArray(64) { (index * 16 + it).toByte() },
            )
        }
        val pdu = MmsPdu.compose("T3", listOf("+33600000000"), "", attachments)

        val parts = MmsPduReader.readRetrieveConf(pdu)!!.parts.drop(1)
        assertEquals(4, parts.size)
        parts.forEachIndexed { index, part ->
            assertEquals("doc$index.pdf", part.name)
            assertTrue(attachments[index].data.contentEquals(part.data))
        }
    }

    // -------------------------------------------------------- cas de terrain

    @Test
    fun `un type de partie en entier court est reconnu`() {
        // 0x1E est `image/jpeg` dans la table WSP : un émetteur a le droit de
        // ne pas l'écrire en clair, et beaucoup le font.
        val body = body(
            part(
                contentTypeBytes = byteArrayOf(0x9E.toByte()), // short-integer 0x1E
                headers = header(0x8E, text("img.jpg")),
                data = byteArrayOf(9, 9, 9),
            )
        )

        val parts = MmsPduReader.readRetrieveConf(minimalHeaders() + body)!!.parts
        assertEquals("image/jpeg", parts.single().contentType)
        assertEquals("img.jpg", parts.single().name)
    }

    @Test
    fun `une partie sans nom retombe sur son content-id`() {
        val body = body(
            part(
                contentTypeBytes = text("image/png"),
                headers = header(0xC0, text("<0>")),
                data = byteArrayOf(1),
            )
        )

        val part = MmsPduReader.readRetrieveConf(minimalHeaders() + body)!!.parts.single()
        assertEquals("image/png", part.contentType)
        assertEquals("0", part.name)
    }

    @Test
    fun `un texte en ISO-8859-1 n'arrive pas en mojibake`() {
        val latin = "Déjà".toByteArray(Charsets.ISO_8859_1)
        val contentType = ByteArrayOutputStream().apply {
            write(text("text/plain"))
            write(0x81) // paramètre charset
            write(0x84) // short-integer 4 = ISO-8859-1
        }.toByteArray()
        val body = body(
            part(
                contentTypeBytes = contentType,
                headers = header(0x8E, text("t.txt")),
                data = latin,
            )
        )

        val part = MmsPduReader.readRetrieveConf(minimalHeaders() + body)!!.parts.single()
        assertEquals(4, part.charset)
        assertEquals("Déjà", part.text())
    }

    // ------------------------------------------------------------- robustesse

    @Test
    fun `un PDU tronque est abandonne, pas explose`() {
        val pdu = MmsPdu.compose(
            transactionId = "T4",
            recipients = listOf("+33600000000"),
            text = "coupé net",
            attachments = listOf(
                MmsPdu.Part("image/jpeg", "<part0>", "p.jpg", ByteArray(512)),
            ),
        )

        // Toutes les coupures possibles, à commencer par celles qui tombent en
        // plein milieu d'un en-tête ou d'une longueur.
        for (length in 1 until pdu.size step 7) {
            MmsPduReader.readRetrieveConf(pdu.copyOfRange(0, length))
        }
        assertNull(MmsPduReader.readRetrieveConf(ByteArray(0)))
        assertNull(MmsPduReader.readRetrieveConf(byteArrayOf(0x00, 0x01, 0x02)))
    }

    @Test
    fun `un nombre de parties aberrant est refuse sans allouer`() {
        // 0xFF 0xFF 0xFF 0x7F : quelque 268 millions de parties annoncées.
        val body = byteArrayOf(0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0x7F)
        assertNull(MmsPduReader.readRetrieveConf(minimalHeaders() + body))
    }

    @Test
    fun `une partie qui deborde du tampon est refusee`() {
        val body = ByteArrayOutputStream().apply {
            write(0x01) // une partie
            write(0x02) // 2 octets d'en-têtes
            write(0x7F) // …mais 127 octets de données annoncés
            write(byteArrayOf(0x8E.toByte(), 0x00))
            write(byteArrayOf(1, 2, 3))
        }.toByteArray()
        assertNull(MmsPduReader.readRetrieveConf(minimalHeaders() + body))
    }

    // ---------------------------------------------------------- notification

    @Test
    fun `une notification de depot livre l'adresse du MMSC`() {
        val pdu = ByteArrayOutputStream().apply {
            write(0x8C); write(0x82) // message-type = m-notification-ind
            write(0x98); write(text("TX-42")) // transaction-id
            write(0x8D); write(0x92) // version 1.2
            write(0x89); write(from("+33612345678/TYPE=PLMN"))
            write(0x8A); write(0x80) // message-class = personal (à ignorer)
            write(0x8E); write(byteArrayOf(0x02, 0x1D, 0x40)) // taille : 7488
            write(0x88); write(byteArrayOf(0x04, 0x81.toByte(), 0x00, 0x01, 0x51)) // expiry
            write(0x83); write(text("http://mms.sfr.fr/?id=42"))
        }.toByteArray()

        val notification = MmsPduReader.readNotification(pdu)!!
        assertEquals("http://mms.sfr.fr/?id=42", notification.contentLocation)
        assertEquals("TX-42", notification.transactionId)
        // Le suffixe `/TYPE=PLMN` dit le plan de numérotation, pas l'adresse :
        // le garder ferait deux fils pour un même correspondant.
        assertEquals("+33612345678", notification.from)
        assertEquals(7488L, notification.messageSize)
    }

    @Test
    fun `une notification sans adresse de contenu est refusee`() {
        val pdu = ByteArrayOutputStream().apply {
            write(0x8C); write(0x82)
            write(0x98); write(text("TX-43"))
        }.toByteArray()
        assertNull(MmsPduReader.readNotification(pdu))
    }

    // ------------------------------------------------------------- fabriques

    /** Les en-têtes minimaux d'un `M-Retrieve.conf`, suivis de son Content-Type. */
    private fun minimalHeaders(): ByteArray = ByteArrayOutputStream().apply {
        write(0x8C); write(0x84) // message-type = m-retrieve-conf
        write(0x8D); write(0x92)
        write(0x89); write(from("+33612345678/TYPE=PLMN"))
        write(0x85); write(byteArrayOf(0x04, 0x67, 0x00, 0x00, 0x00)) // date
        write(0x84) // content-type, dernier par la spec
        write(valueLength(byteArrayOf(0xB3.toByte()))) // multipart/related
    }.toByteArray()

    private fun body(vararg parts: ByteArray): ByteArray =
        ByteArrayOutputStream().apply {
            write(parts.size)
            parts.forEach { write(it) }
        }.toByteArray()

    private fun part(
        contentTypeBytes: ByteArray,
        headers: ByteArray,
        data: ByteArray,
    ): ByteArray {
        val allHeaders = valueLength(contentTypeBytes) + headers
        return ByteArrayOutputStream().apply {
            write(allHeaders.size)
            write(data.size)
            write(allHeaders)
            write(data)
        }.toByteArray()
    }

    private fun header(field: Int, value: ByteArray): ByteArray =
        byteArrayOf(field.toByte()) + value

    private fun text(value: String): ByteArray =
        value.toByteArray(Charsets.UTF_8) + byteArrayOf(0)

    private fun valueLength(value: ByteArray): ByteArray =
        byteArrayOf(value.size.toByte()) + value

    /** `From` : longueur, jeton « adresse présente », puis l'adresse encodée. */
    private fun from(address: String): ByteArray {
        val encoded = ByteArrayOutputStream().apply {
            write(0xEA) // charset UTF-8
            write(address.toByteArray(Charsets.UTF_8))
            write(0)
        }.toByteArray()
        val value = byteArrayOf(0x80.toByte()) + valueLength(encoded)
        return valueLength(value)
    }
}
