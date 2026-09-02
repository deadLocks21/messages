package fr.dtfh.messages

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Tests du calcul des participants d'un MMS reçu.
 *
 * C'est ce calcul qui décide du fil, et le seul endroit où le défaut d'origine
 * — un MMS de groupe rangé en tête-à-tête avec son expéditeur — se répare. Il
 * est **pur**, donc entièrement vérifiable ici : le reste de la réception
 * demande un opérateur, celui-ci non.
 *
 * Le vrai `thread_id`, lui, est calculé par le provider Telephony et ne se
 * rejoue pas sur la JVM. Ce qu'on prouve ici, c'est que le **jeu d'adresses**
 * qu'on lui passera à la réception est le même qu'à l'émission ; qu'il en tire
 * le même fil est la promesse de `getOrCreateThreadId`, pas la nôtre.
 */
class MmsParticipantsTest {

    private val moi = "+33698765432"

    @Test
    fun `l'expediteur fait partie du fil`() {
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf(moi),
            cc = emptyList(),
            self = moi,
        )

        assertEquals(listOf("+33611111111"), participants)
    }

    @Test
    fun `notre propre numero est retire, quelle que soit sa forme`() {
        // Le PDU porte le numéro tel que l'émetteur l'a écrit : rien ne dit
        // qu'il aura la forme sous laquelle l'appareil nous le rend.
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf("0698765432", "+33622222222"),
            cc = emptyList(),
            self = moi,
        )

        assertEquals(listOf("+33611111111", "+33622222222"), participants)
    }

    @Test
    fun `deux formes du meme numero ne font qu'un participant`() {
        // Deux entrées pour une personne feraient un faux groupe — donc un fil
        // de plus, pour les mêmes gens.
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf("0611111111", "+33622222222", "0622222222"),
            cc = emptyList(),
            self = moi,
        )

        assertEquals(listOf("+33611111111", "+33622222222"), participants)
    }

    @Test
    fun `un Cc participe au meme titre qu'un To`() {
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf(moi),
            cc = listOf("+33633333333"),
            self = moi,
        )

        assertEquals(listOf("+33611111111", "+33633333333"), participants)
    }

    @Test
    fun `sans numero de ligne, un destinataire unique est forcement nous`() {
        // Le MMSC nous a livré le message : nous sommes dans sa liste. S'il n'y
        // a qu'un destinataire, c'est nous — et le tête-à-tête doit rester ce
        // qu'il était avant ce correctif, sur un appareil qui ne connaît pas
        // son propre numéro comme sur les autres.
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf(moi),
            cc = emptyList(),
            self = null,
        )

        assertEquals(listOf("+33611111111"), participants)
    }

    @Test
    fun `un numero de ligne inconnu garde le jeu entier`() {
        // Plusieurs destinataires et pas de numéro de ligne : rien ne dit
        // lequel est nous. Garder une adresse de trop crée un fil de plus ; en
        // retirer une au jugé rangerait le message dans le fil de quelqu'un
        // d'autre.
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf(moi, "+33622222222"),
            cc = emptyList(),
            self = null,
        )

        assertEquals(listOf("+33611111111", moi, "+33622222222"), participants)
    }

    @Test
    fun `un tete-a-tete ne devient pas un groupe`() {
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = emptyList(),
            cc = emptyList(),
            self = moi,
        )

        assertEquals(listOf("+33611111111"), participants)
    }

    @Test
    fun `une adresse vide ne fait pas un participant`() {
        val participants = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf("", "   "),
            cc = emptyList(),
            self = moi,
        )

        assertEquals(listOf("+33611111111"), participants)
    }

    @Test
    fun `retirer soi-meme ne vide jamais le jeu`() {
        // Un PDU où nous serions le seul participant ne désignerait aucun fil.
        // Aucun MMS légitime n'a cette forme, mais le réseau n'est pas tenu
        // d'en produire.
        val participants = MmsParticipants.of(
            sender = moi,
            to = emptyList(),
            cc = emptyList(),
            self = moi,
        )

        assertEquals(listOf(moi), participants)
    }

    // ----------------------------------------------------- critère d'acceptation

    @Test
    fun `le jeu recu est celui de l'envoi`() {
        // Ce que l'app passe à `getOrCreateThreadId` quand *elle* écrit au
        // groupe (cf. `MmsStore.sendMessage`).
        val envoi = setOf("+33611111111", "+33622222222")

        // Ce que le même groupe nous renvoie : l'un des deux répond à tous, et
        // le PDU nous compte parmi ses destinataires.
        val reception = MmsParticipants.of(
            sender = "+33611111111",
            to = listOf("0622222222", moi),
            cc = emptyList(),
            self = moi,
        ).toSet()

        // La comparaison se fait sur les clés d'adresse, comme le provider le
        // fera : les formes diffèrent, les correspondants non. Si ces deux jeux
        // divergeaient, le groupe se dédoublerait — un fil pour ce qu'on
        // reçoit, un autre pour ce qu'on envoie — et le défaut n'aurait été que
        // déplacé.
        assertEquals(envoi.map(AddressKey::of).toSet(), reception.map(AddressKey::of).toSet())
    }
}
