package fr.dtfh.messages

/**
 * Qui participe à un MMS reçu — et donc dans quel fil il se range.
 *
 * Un MMS de groupe ne se distingue d'un tête-à-tête par **rien d'autre** que
 * ses en-têtes d'adresses : le PDU porte un `From` et autant de `To` (ou de
 * `Cc`) qu'il y a de destinataires. Ne lire que le `From`, c'est ranger la
 * réponse de quelqu'un à tout le monde dans le fil privé qu'on a avec lui — et
 * répondre à lui seul sans le savoir.
 *
 * Le jeu rendu est celui que `Telephony.Threads.getOrCreateThreadId` attend :
 * les **autres**, nous exclus. C'est aussi celui que
 * [MmsStore.sendMessage] lui passe à l'émission ; les deux doivent coïncider,
 * sinon le groupe se dédouble en deux fils — un pour ce qu'on reçoit, un pour
 * ce qu'on envoie — et le défaut n'aura été que déplacé.
 *
 * Calcul **pur** : ni `Context`, ni provider, ni journal. C'est ce qui le rend
 * vérifiable sur la JVM, là où le reste de la réception demande un opérateur.
 */
object MmsParticipants {

    /**
     * L'expéditeur, ses co-destinataires, nous en moins.
     *
     * [self] est le numéro de notre propre ligne — `null` quand l'appareil ne
     * le connaît pas, ce qui arrive (SIM muette, MSISDN non provisionné). Voir
     * alors le repli, plus bas : il n'est pas « ne rien retirer ».
     *
     * Les doublons de forme (`+33612345678` et `0612345678` dans le même PDU)
     * sont fondus par [AddressKey] : deux entrées pour une personne feraient un
     * faux groupe. La forme retenue est la première rencontrée.
     *
     * @return les participants sans doublon, **l'expéditeur en tête**.
     */
    fun of(
        sender: String,
        to: List<String>,
        cc: List<String>,
        self: String?,
    ): List<String> {
        val byKey = LinkedHashMap<String, String>()
        for (address in sequenceOf(sender) + to.asSequence() + cc.asSequence()) {
            val trimmed = address.trim()
            if (trimmed.isEmpty()) continue
            val key = AddressKey.of(trimmed)
            if (!byKey.containsKey(key)) byKey[key] = trimmed
        }
        val participants = byKey.values.toList()

        if (self != null) {
            val others = byKey.filterKeys { it != AddressKey.of(self) }.values.toList()
            // Un jeu vide ne désignerait aucun fil : plutôt garder notre propre
            // adresse — un fil avec soi-même se voit — que rendre le message
            // impossible à ranger. Le cas suppose un PDU où nous sommes le seul
            // participant, ce qu'aucun MMS légitime ne produit.
            return others.ifEmpty { participants }
        }

        // Numéro de la ligne inconnu. Une seule chose reste certaine : le MMSC
        // nous a livré ce message, donc **nous figurons dans sa liste de
        // destinataires**. S'il n'y en a qu'un, c'est nous — déduction, pas
        // devinette — et le tête-à-tête reste celui qu'il était avant ce
        // correctif. Sans cette ligne, tout MMS reçu en privé sur un appareil
        // qui ignore son propre numéro atterrirait dans un fil « lui + moi »
        // distinct du fil de ses SMS : une régression bien plus fréquente que
        // le défaut qu'on répare.
        if (participants.size == 2) return participants.take(1)

        // Plusieurs destinataires, et rien pour dire lequel est nous : le jeu
        // reste **entier** plutôt qu'amputé au jugé. Une adresse de trop fait
        // un fil de plus — visible, et qui se répare dès que l'appareil connaît
        // son numéro ; une adresse retirée au hasard rangerait le message dans
        // le fil de quelqu'un d'autre.
        return participants
    }
}
