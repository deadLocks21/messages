package fr.dtfh.messages

/**
 * Clé de comparaison d'une adresse : deux adresses désignent-elles la même
 * personne ?
 *
 * Calquée sur `PhoneNumberUtils.compare` d'Android — et sur `Address.key` côté
 * Dart, dont elle est le jumeau natif : les **9 derniers chiffres
 * significatifs** (`+33612345678` ≡ `0612345678`), ou l'adresse en majuscules
 * pour un expéditeur alphanumérique (`ORANGE`).
 *
 * Une seule implémentation native, ici, parce que deux copies dérivent : le
 * répertoire des notifications ne retrouverait plus les noms, ou un MMS de
 * groupe se rangerait dans un fil jumeau du bon. Elle doit en revanche rester
 * alignée sur `Address.key` — c'est la couche Dart qui publie les clés du
 * répertoire, et le natif qui les relit.
 */
object AddressKey {

    /** Nombre de chiffres de fin qui suffisent à identifier un correspondant. */
    private const val SIGNIFICANT_DIGITS = 9

    fun of(raw: String): String {
        val digits = raw.filter { it.isDigit() }
        if (digits.isEmpty()) return raw.trim().uppercase()
        return if (digits.length <= SIGNIFICANT_DIGITS) {
            digits
        } else {
            digits.takeLast(SIGNIFICANT_DIGITS)
        }
    }
}
