package fr.dtfh.messages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests du découpage en segments.
 *
 * Ce découpage remplace `SmsManager.divideMessage`, qu'on ne peut pas appeler
 * sans `READ_PHONE_STATE` (cf. [SmsSegments]). Il décide donc seul de ce qui
 * part sur le réseau — et c'est la seule pièce de l'envoi qui se vérifie sans
 * téléphone. D'où ces tests.
 *
 * Les deux propriétés qui comptent : **rien ne se perd** — la concaténation des
 * segments rend le corps d'origine, caractère pour caractère — et **rien ne
 * déborde** — aucun segment ne dépasse ce qu'un SMS concaténé peut porter.
 */
class SmsSegmentsTest {

    // --------------------------------------------------------------- 7 bits

    @Test
    fun `un message court part en un seul segment`() {
        assertEquals(listOf("Bonjour"), SmsSegments.divide("Bonjour"))
    }

    @Test
    fun `un message vide reste un segment`() {
        assertEquals(listOf(""), SmsSegments.divide(""))
    }

    @Test
    fun `160 caracteres tiennent encore dans un segment`() {
        val body = "a".repeat(160)
        assertEquals(listOf(body), SmsSegments.divide(body))
    }

    @Test
    fun `au-dela de 160 caracteres les segments tombent a 153`() {
        val body = "a".repeat(161)
        val parts = SmsSegments.divide(body)

        assertEquals(2, parts.size)
        assertEquals(153, parts[0].length)
        assertEquals(8, parts[1].length)
        assertEquals(body, parts.joinToString(""))
    }

    @Test
    fun `les accents de l'alphabet GSM ne font pas basculer en UCS-2`() {
        // « é », « à », « ù » et « è » sont dans la table par défaut : un tel
        // message garde ses 160 caractères par segment.
        val body = "éàùè".repeat(40)
        assertEquals(160, body.length)
        assertEquals(listOf(body), SmsSegments.divide(body))
    }

    @Test
    fun `une paire d'echappement ne se coupe pas en deux`() {
        // « € » coûte deux septets. Placé de sorte que le 153e septet tombe au
        // milieu de la paire, il doit ouvrir le segment suivant plutôt que de
        // se retrouver à cheval sur les deux.
        val body = "a".repeat(152) + "€" + "b".repeat(20)
        val parts = SmsSegments.divide(body)

        assertEquals(2, parts.size)
        assertEquals("a".repeat(152), parts[0])
        assertTrue(parts[1].startsWith("€"))
        assertEquals(body, parts.joinToString(""))
    }

    // ---------------------------------------------------------------- UCS-2

    @Test
    fun `un seul caractere hors alphabet GSM fait basculer tout le message`() {
        // « ê » n'est pas dans la table GSM : le message entier passe en
        // UCS-2, et 71 caractères ne tiennent plus dans un segment.
        val body = "ê" + "a".repeat(70)
        val parts = SmsSegments.divide(body)

        assertEquals(2, parts.size)
        assertEquals(67, parts[0].length)
        assertEquals(body, parts.joinToString(""))
    }

    @Test
    fun `le c cedille minuscule n'est pas dans l'alphabet GSM`() {
        // Contre-intuitif, mais conforme au 3GPP TS 23.038 comme à AOSP : la
        // table ne contient que le « Ç » majuscule. Un « ç » fait donc tomber
        // la capacité d'un segment de 160 à 70 caractères.
        val body = "ç".repeat(71)
        assertEquals(2, SmsSegments.divide(body).size)
        assertEquals(listOf("Ç".repeat(71)), SmsSegments.divide("Ç".repeat(71)))
    }

    @Test
    fun `70 caracteres UCS-2 tiennent dans un segment`() {
        val body = "ê".repeat(70)
        assertEquals(listOf(body), SmsSegments.divide(body))
    }

    @Test
    fun `le cas du bug - un message accentue de 77 caracteres fait deux segments`() {
        // Le corps qui échouait en production : le « û » de « sûre » sort de
        // la table GSM, donc UCS-2, donc deux segments, donc le chemin
        // multi-parties — et l'appel protégé de `divideMessage`.
        val body = "Réunion décalée à seize heures trente, prévois ton parapluie et ta veste sûre"
        assertEquals(77, body.length)

        val parts = SmsSegments.divide(body)
        assertEquals(2, parts.size)
        assertEquals(67, parts[0].length)
        assertEquals(body, parts.joinToString(""))
    }

    @Test
    fun `un emoji n'est jamais coupe en deux moities`() {
        // 66 caractères puis un emoji : la limite de 67 unités UTF-16 tombe
        // pile au milieu de la paire de substitution.
        val body = "ê".repeat(66) + "😀" + "ê".repeat(20)
        val parts = SmsSegments.divide(body)

        assertEquals(66, parts[0].length)
        assertTrue(parts[1].startsWith("😀"))
        assertEquals(body, parts.joinToString(""))
        for (part in parts) {
            assertTrue(part.isEmpty() || !part.last().isHighSurrogate())
        }
    }

    // ------------------------------------------------------------ propriétés

    @Test
    fun `aucun segment 7 bits ne depasse 153 septets`() {
        val bodies = listOf(
            "a".repeat(1000),
            "€".repeat(300),
            "Bonjour ! Ça va ?".repeat(50),
        )
        for (body in bodies) {
            val parts = SmsSegments.divide(body)
            assertEquals(body, parts.joinToString(""))
            for (part in parts) {
                // Un « € » compte double : c'est le coût en septets, pas le
                // nombre de caractères, qui est plafonné.
                val septets = part.sumOf { if (it == '€') 2 else 1 }
                assertTrue(septets <= 153)
            }
        }
    }

    @Test
    fun `aucun segment UCS-2 ne depasse 67 unites`() {
        val bodies = listOf(
            "ê".repeat(1000),
            "😀".repeat(200),
            "Où êtes-vous ? Rendez-vous à 18 h.".repeat(20),
        )
        for (body in bodies) {
            val parts = SmsSegments.divide(body)
            assertEquals(body, parts.joinToString(""))
            for (part in parts) assertTrue(part.length <= 67)
        }
    }
}
