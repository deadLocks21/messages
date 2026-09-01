package fr.dtfh.messages

/**
 * Découpe d'un SMS en segments, sans passer par `SmsManager.divideMessage`.
 *
 * ## Pourquoi ne pas laisser Android le faire
 *
 * `SmsManager.divideMessage` délègue à `android.telephony.SmsMessage
 * .fragmentText`, qui, **dans la seule branche UCS-2 à plus d'un segment**,
 * appelle `hasEmsSupport()`. Cette méthode lit `getSimOperatorNumeric()` puis
 * `getGroupIdLevel1()` pour savoir si l'opérateur de la SIM figure dans la
 * liste système `no_ems_support_sim_operators` — les rares réseaux incapables
 * de porter un message concaténé.
 *
 * Or `getGroupIdLevel1()` est protégée par `READ_PHONE_STATE`, et le
 * `Binder.clearCallingIdentity()` posé autour n'y change rien : il neutralise
 * l'identité des appels qu'on *reçoit*, pas celle que le processus téléphonie
 * voit de l'appel qu'on *émet*. Une application SMS qui ne déclare pas
 * `READ_PHONE_STATE` prend donc une `SecurityException` sur tout message
 * accentué de deux segments ou plus — un texte français d'un peu plus de 70
 * caractères.
 *
 * Déclarer `READ_PHONE_STATE` réparerait l'envoi, au prix d'une demande
 * d'accès au groupe « Téléphone » que rien, du point de vue de l'utilisateur,
 * ne justifie dans une application de SMS. On paierait cette permission pour
 * une branche qui ne sert qu'à un opérateur néerlandais (MCC/MNC 204 04),
 * jamais à un abonné français. D'où ce découpage-ci, qui ne demande rien à
 * personne — et qui, contrairement à celui d'AOSP, se teste sur la JVM.
 *
 * ## Ce qui est délibérément laissé de côté
 *
 * Le repli « pas d'EMS » d'AOSP — deux caractères de moins par segment pour y
 * loger un « x/y » en clair — n'est pas repris : il suppose justement la
 * lecture de la SIM qu'on refuse de faire. Sur un réseau sans EMS, nos
 * segments arriveraient donc séparés au lieu d'être recollés. Les tables de
 * langue nationales du GSM 7 bits ne le sont pas non plus : Android ne les
 * active que sur configuration opérateur, et aucun réseau français ne le fait.
 *
 * Le découpage lui-même est celui du 3GPP TS 23.038 : alphabet GSM 7 bits
 * quand tout le texte y tient, UCS-2 sinon.
 */
object SmsSegments {

    /**
     * Alphabet GSM 7 bits par défaut (3GPP TS 23.038 §6.2.1), échappement
     * (0x1B) exclu : il n'encode aucun caractère saisissable, il n'annonce que
     * la table d'extension.
     */
    private val BASIC = (
        "@£\$¥èéùìòÇ\nØø\rÅå" +
            "Δ_ΦΓΛΩΠΨΣΘΞÆæßÉ" +
            " !\"#¤%&'()*+,-./" +
            "0123456789:;<=>?" +
            "¡ABCDEFGHIJKLMNO" +
            "PQRSTUVWXYZÄÖÑÜ§" +
            "¿abcdefghijklmno" +
            "pqrstuvwxyzäöñüà"
        ).toSet()

    /**
     * Table d'extension : ces caractères s'écrivent en deux septets
     * (échappement + code), et la paire ne se coupe pas entre deux segments.
     */
    private val EXTENDED = "^{}\\[~]|€".toSet()

    /** Un SMS 7 bits qui part seul : 140 octets, soit 160 septets. */
    private const val SEPTETS_SINGLE = 160

    /** Concaténé : l'en-tête UDH mange 6 octets, il reste 153 septets. */
    private const val SEPTETS_CONCATENATED = 153

    /** Un SMS UCS-2 qui part seul : 140 octets, soit 70 caractères. */
    private const val UNITS_SINGLE = 70

    /** Concaténé : 134 octets, soit 67 caractères. */
    private const val UNITS_CONCATENATED = 67

    /**
     * Les segments à confier à `sendMultipartTextMessage`, dans l'ordre.
     *
     * Un corps qui tient dans un seul segment rend une liste d'un élément —
     * c'est ce que fait `divideMessage`, et c'est ce qui laisse à l'envoi un
     * seul chemin de code quelle que soit la longueur du message.
     */
    fun divide(body: String): List<String> {
        val septets = septetCost(body)
        return if (septets != null) divideSeptets(body, septets) else divideUnits(body)
    }

    /**
     * Coût du corps en septets, ou `null` dès qu'un caractère sort de
     * l'alphabet GSM — auquel cas le message entier part en UCS-2. C'est la
     * règle du SMS : l'encodage vaut pour le message, pas caractère par
     * caractère. Un seul « ê » suffit donc à faire tomber la capacité d'un
     * segment de 160 à 70.
     */
    private fun septetCost(body: String): Int? {
        var total = 0
        for (character in body) {
            total += septetsOf(character) ?: return null
        }
        return total
    }

    private fun septetsOf(character: Char): Int? = when (character) {
        in BASIC -> 1
        in EXTENDED -> 2
        else -> null
    }

    private fun divideSeptets(body: String, total: Int): List<String> {
        if (total <= SEPTETS_SINGLE) return listOf(body)

        val parts = mutableListOf<String>()
        val current = StringBuilder()
        var cost = 0
        for (character in body) {
            val septets = septetsOf(character) ?: 1
            // Le segment se ferme *avant* d'ajouter le caractère : une paire
            // d'échappement qui ne tient plus part entière dans le suivant,
            // jamais à cheval sur les deux.
            if (cost + septets > SEPTETS_CONCATENATED) {
                parts.add(current.toString())
                current.setLength(0)
                cost = 0
            }
            current.append(character)
            cost += septets
        }
        if (current.isNotEmpty()) parts.add(current.toString())
        return parts
    }

    private fun divideUnits(body: String): List<String> {
        if (body.length <= UNITS_SINGLE) return listOf(body)

        val parts = mutableListOf<String>()
        var start = 0
        while (start < body.length) {
            var end = minOf(start + UNITS_CONCATENATED, body.length)
            // Un emoji sort du plan de base : il occupe deux unités UTF-16.
            // Les séparer donnerait deux moitiés de caractère, que le
            // destinataire verrait comme deux losanges.
            if (end < body.length && Character.isHighSurrogate(body[end - 1])) end--
            parts.add(body.substring(start, end))
            start = end
        }
        return parts
    }
}
