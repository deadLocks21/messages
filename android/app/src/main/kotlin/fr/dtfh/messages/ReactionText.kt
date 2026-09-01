package fr.dtfh.messages

/**
 * Les réactions, vues du natif.
 *
 * Une réaction n'est pas un champ d'un SMS : c'est un SMS, dont le corps imite
 * la phrase qu'un iPhone envoie quand il « tapback » un correspondant Android
 * (`Liked “Bonjour”`). Le repli, lui, est côté Dart — [ReactionCodec] — et
 * c'est là qu'il doit rester.
 *
 * Sauf ici. Le récepteur `SMS_DELIVER` s'exécute **sans moteur Dart** : au
 * moment de notifier, il ne peut demander à personne ce que cette phrase veut
 * dire. Sans ce décodeur, une réaction reçue s'annoncerait dans le volet sous
 * la forme `Liked “On se voit demain ?”` — exactement le texte que l'app passe
 * son temps à ne plus montrer.
 *
 * On n'en reprend donc que le strict nécessaire : reconnaître, et reformuler.
 * Retrouver le message visé demanderait de relire le fil, ce qui est le travail
 * du repli, et il se fera à l'ouverture de l'app.
 */
object ReactionText {

    /** Verbe iOS → emoji, dans la table de Google Messages. */
    private val VERBS = mapOf(
        "liked" to "👍",
        "loved" to "😍",
        "laughed at" to "😂",
        "emphasized" to "😮",
        "disliked" to "👎",
        "questioned" to "🤔",
        "a aimé" to "👍",
        "aimé" to "👍",
        "a adoré" to "😍",
        "adoré" to "😍",
        "a ri de" to "😂",
        "ri de" to "😂",
        "a mis en avant" to "😮",
        "a souligné" to "😮",
        "n'a pas aimé" to "👎",
        "pas aimé" to "👎",
        "s'est interrogé sur" to "🤔",
        "a questionné" to "🤔",
    )

    private val VERB_PATTERN = Regex(
        "^(${VERBS.keys.joinToString("|") { Regex.escape(it) }})\\s+(.+)$",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )

    private val REACTED_PATTERN = Regex(
        "^(?:reacted|a réagi(?: avec)?)\\s+(\\S+)\\s+(?:to|à|au)\\s+(.+)$",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )

    private val BARE_PATTERN = Regex(
        "^(\\S+)\\s+(?:to|à)\\s+(.+)$",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )

    private val REMOVAL_PATTERN = Regex(
        "^(?:removed|a retiré|a enlevé)\\s+.+?\\s+(?:from|de|à)\\s+(.+)$",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )

    /**
     * Ce qu'on affiche à la place du corps brut, ou `null` si ce message n'est
     * pas une réaction — auquel cas il s'affiche tel quel, comme avant.
     */
    fun humanize(body: String): String? {
        val text = stripInvisible(body).trim()
        if (text.isEmpty()) return null

        REMOVAL_PATTERN.find(text)?.let {
            return "Réaction retirée à ${quote(it.groupValues[1])}"
        }
        VERB_PATTERN.find(text)?.let { match ->
            val emoji = VERBS[match.groupValues[1].lowercase()] ?: return@let
            return "$emoji Réaction à ${quote(match.groupValues[2])}"
        }
        REACTED_PATTERN.find(text)?.let { match ->
            val emoji = match.groupValues[1]
            if (!looksLikeEmoji(emoji)) return@let
            return "$emoji Réaction à ${quote(match.groupValues[2])}"
        }
        BARE_PATTERN.find(text)?.let { match ->
            val emoji = match.groupValues[1]
            if (!looksLikeEmoji(emoji)) return@let
            return "$emoji Réaction à ${quote(match.groupValues[2])}"
        }
        return null
    }

    /** Le corps à afficher : reformulé si c'est une réaction, tel quel sinon. */
    fun display(body: String): String = humanize(body) ?: body

    /** La citation, ramenée à des guillemets français et raccourcie. */
    private fun quote(raw: String): String {
        var text = raw.trim().trim('“', '”', '"', '«', '»').trim()
        if (text.length > MAX_QUOTE) {
            text = text.take(MAX_QUOTE).trimEnd() + "…"
        }
        return "« $text »"
    }

    private const val MAX_QUOTE = 40

    /**
     * Les caractères **invisibles** qu'une application glisse dans son texte.
     *
     * Google Messages encadre l'emoji de ses réactions d'espaces de largeur
     * nulle (`U+200B`) : rien ne se voit, et c'est pourtant assez pour qu'un
     * emoji cesse d'en être un aux yeux de [looksLikeEmoji]. La jonction
     * `U+200D` n'est pas de la partie — c'est elle qui tient les séquences
     * d'un seul tenant.
     */
    private val INVISIBLE = setOf(
        0x200B, 0x2060, 0xFEFF, 0x200E, 0x200F, 0x061C, 0x00AD, 0x180E,
    )

    private fun stripInvisible(text: String): String {
        val points = text.codePoints().filter { it !in INVISIBLE }.toArray()
        return String(points, 0, points.size)
    }

    /**
     * Ce jeton est-il un emoji, et rien d'autre ?
     *
     * Le motif `👍 to …` est trop ouvert pour être cru sur parole : sans ce
     * filtre, « Merci to be fair » deviendrait une réaction.
     */
    private fun looksLikeEmoji(token: String): Boolean {
        val points = token.codePoints().toArray()
        if (points.isEmpty() || points.size > 6) return false
        var pictographic = false
        for (point in points) {
            if (point == 0x200D || point == 0x20E3 || point == 0xFE0F ||
                point == 0xFE0E || point in 0x1F3FB..0x1F3FF
            ) {
                continue
            }
            if (isPictographic(point)) {
                pictographic = true
                continue
            }
            return false
        }
        return pictographic
    }

    private fun isPictographic(point: Int): Boolean =
        point in 0x1F000..0x1FAFF ||
            point in 0x2600..0x27BF ||
            point in 0x2B00..0x2BFF ||
            point in 0x2190..0x21FF ||
            point in 0x2300..0x23FF ||
            point == 0x203C ||
            point == 0x2049 ||
            point == 0x2139
}
