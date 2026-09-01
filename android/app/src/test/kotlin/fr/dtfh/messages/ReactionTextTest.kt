package fr.dtfh.messages

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests du décodeur de réactions du natif.
 *
 * Il double celui de Dart (`ReactionCodec`) parce que le récepteur
 * `SMS_DELIVER` notifie sans moteur Dart. Deux implémentations d'un même
 * format dérivent : ces tests sont le miroir de `reaction_codec_test.dart`, et
 * c'est délibéré — ce qui est vrai là-bas doit l'être ici.
 */
class ReactionTextTest {

    @Test
    fun `un tapback iOS s'annonce comme une reaction`() {
        assertEquals(
            "👍 Réaction à « On se voit demain ? »",
            ReactionText.humanize("Liked “On se voit demain ?”"),
        )
        assertEquals(
            "😂 Réaction à « Bonjour »",
            ReactionText.humanize("Laughed at \"Bonjour\""),
        )
    }

    @Test
    fun `la table est celle de Google Messages`() {
        assertTrue(ReactionText.humanize("Loved “A”")!!.startsWith("😍"))
        assertTrue(ReactionText.humanize("Emphasized “A”")!!.startsWith("😮"))
        assertTrue(ReactionText.humanize("Questioned “A”")!!.startsWith("🤔"))
        assertTrue(ReactionText.humanize("Disliked “A”")!!.startsWith("👎"))
    }

    @Test
    fun `la forme emoji d'iOS 18 et celle de Google Messages`() {
        assertEquals(
            "😢 Réaction à « Bonjour »",
            ReactionText.humanize("Reacted 😢 to “Bonjour”"),
        )
        assertEquals(
            "😂 Réaction à « Bonjour »",
            ReactionText.humanize("😂 to Bonjour"),
        )
    }

    @Test
    fun `la forme francaise d'un iPhone localise`() {
        assertEquals(
            "👍 Réaction à « Bonjour »",
            ReactionText.humanize("A aimé « Bonjour »"),
        )
    }

    @Test
    fun `un retrait se dit comme un retrait`() {
        assertEquals(
            "Réaction retirée à « Bonjour »",
            ReactionText.humanize("Removed a heart from “Bonjour”"),
        )
    }

    @Test
    fun `une phrase ordinaire n'est pas une reaction`() {
        assertNull(ReactionText.humanize("Bonjour, ça va ?"))
        assertNull(ReactionText.humanize("Merci to be fair"))
        assertNull(ReactionText.humanize("Je passe à la maison"))
        assertNull(ReactionText.humanize(""))
        assertNull(ReactionText.humanize("Liked"))
    }

    @Test
    fun `un message ordinaire s'affiche tel quel`() {
        assertEquals("Bonjour", ReactionText.display("Bonjour"))
    }

    @Test
    fun `une longue citation est raccourcie`() {
        val long = "a".repeat(200)

        val shown = ReactionText.humanize("Liked “$long”")!!

        assertTrue(shown.endsWith("… »"))
        assertTrue(shown.length < 60)
    }

    @Test
    fun `une reaction en echec s'annonce comme une reaction`() {
        // Le volet « Message non envoyé » montre le corps expédié : celui d'une
        // réaction n'est pas une phrase que l'utilisateur a écrite.
        assertEquals(
            "👍 Réaction à « Bonjour »",
            ReactionText.display("Liked “Bonjour”"),
        )
    }

    @Test
    fun `la forme reelle de Google Messages, invisibles compris`() {
        // Relevé dans le stock d'un Pixel : espaces de largeur nulle autour de
        // l'emoji, espaces fins autour de la citation.
        val received = "\u200a\u200b\uD83D\uDC4D\u200b à \"\u200aJ'ai besoin du code stp\u200a\"\u200a"

        assertEquals(
            "👍 Réaction à « J'ai besoin du code stp »",
            ReactionText.humanize(received),
        )
    }
}
