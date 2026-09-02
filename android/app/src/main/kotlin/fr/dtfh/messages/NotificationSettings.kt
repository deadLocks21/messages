package fr.dtfh.messages

import android.content.Context
import org.json.JSONObject

/**
 * Ce que la couche Dart pousse à l'avance pour que les notifications soient
 * correctes : les fils en sourdine, et l'annuaire `clé d'adresse → nom`.
 *
 * Stocké dans un `SharedPreferences` **détenu par le natif** plutôt que lu
 * depuis celui du plugin `shared_preferences` : le format de ce dernier est un
 * détail d'implémentation du plugin, pas un contrat. Ici le contrat est
 * explicite, c'est le canal `setMutedThreads` / `setNotificationDirectory`.
 *
 * Lu depuis `SmsDeliverReceiver`, qui s'exécute sans moteur Dart : rien ici ne
 * doit dépendre de Flutter.
 */
object NotificationSettings {
    private const val PREFS = "fr.dtfh.messages.notifications"

    /**
     * Fil → échéance de la sourdine, en millisecondes d'époque ; `0` pour
     * « sans fin ». Clé distincte de l'ancien `muted_threads`, qui était un
     * `StringSet` : relire un `StringSet` comme une `String` lève, et une mise
     * à jour de l'app doit repartir proprement plutôt que planter le
     * récepteur. Le premier retour au premier plan republie tout de toute
     * façon.
     */
    private const val KEY_MUTED_UNTIL = "muted_threads_until"
    private const val KEY_NAMES = "directory"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun setMutedThreads(context: Context, mutedUntil: Map<String, Long>) {
        prefs(context)
            .edit()
            .putString(KEY_MUTED_UNTIL, JSONObject(mutedUntil as Map<*, *>).toString())
            .apply()
    }

    /**
     * Le fil notifie-t-il maintenant ? Une veille échue ne coupe plus rien, et
     * personne n'a eu à la nettoyer — c'est tout l'intérêt de publier une date
     * plutôt qu'un booléen, le récepteur tournant sans moteur Dart.
     */
    fun isMuted(context: Context, threadId: String): Boolean {
        val raw = prefs(context).getString(KEY_MUTED_UNTIL, null) ?: return false
        return runCatching {
            val until = JSONObject(raw)
            if (!until.has(threadId)) return false
            val deadline = until.optLong(threadId, 0L)
            deadline == 0L || deadline > System.currentTimeMillis()
        }.getOrDefault(false)
    }

    fun setDirectory(context: Context, names: Map<String, String>) {
        prefs(context).edit().putString(KEY_NAMES, JSONObject(names).toString()).apply()
    }

    /** Nom du contact pour une adresse, ou `null` si elle est inconnue. */
    fun nameFor(context: Context, address: String): String? {
        val raw = prefs(context).getString(KEY_NAMES, null) ?: return null
        return runCatching {
            // Les clés de l'annuaire sont celles que publie `Address.key` côté
            // Dart : la normalisation doit être la même des deux côtés, d'où
            // [AddressKey] plutôt qu'une copie de plus.
            JSONObject(raw).optString(AddressKey.of(address)).takeIf { it.isNotEmpty() }
        }.getOrNull()
    }
}
