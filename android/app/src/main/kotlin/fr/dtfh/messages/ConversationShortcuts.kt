package fr.dtfh.messages

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

/**
 * Le raccourci de conversation d'un fil.
 *
 * Android ne connaît pas les fils d'une app de messagerie : il connaît des
 * **raccourcis longue durée** portant une `Person`. C'est ce qui range une
 * notification dans la section « Conversations » du volet, autorise les bulles,
 * et — la raison pour laquelle on les pose ici — fait exister les *réglages de
 * notification du fil*, ceux que l'app d'origine ouvre depuis sa ligne
 * « Notifications ». Sans raccourci, il n'y a pas de fil à régler, et l'écran
 * système n'a rien à afficher.
 *
 * Le raccourci est reposé à chaque notification : `pushDynamicShortcut` gère la
 * rotation quand le quota de l'appareil est atteint, en écartant le moins
 * récemment utilisé. C'est exactement le comportement voulu — les fils qui
 * notifient sont ceux qui méritent leur place.
 *
 * Appelé depuis un récepteur qui tourne sans moteur Dart : rien ici ne doit
 * dépendre de Flutter.
 */
object ConversationShortcuts {
    /** Identifiant stable d'un fil, aussi utilisé comme `conversationId`. */
    fun idFor(threadId: String): String = "thread_$threadId"

    fun push(context: Context, threadId: String, address: String, name: String): String {
        val id = idFor(threadId)
        val person = Person.Builder()
            .setName(name)
            .setKey(address)
            .setImportant(true)
            .build()

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("sms:$address")).apply {
            setPackage(context.packageName)
        }

        runCatching {
            ShortcutManagerCompat.pushDynamicShortcut(
                context,
                ShortcutInfoCompat.Builder(context, id)
                    .setShortLabel(name)
                    .setLongLived(true)
                    .setPerson(person)
                    .setCategories(setOf(SHARE_CATEGORY))
                    .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
                    .setIntent(intent)
                    .build(),
            )
        }
        return id
    }

    /**
     * Catégorie du partage direct. Déclarée pour la forme : elle n'ouvre rien
     * tant que le manifeste ne publie pas de `shortcuts.xml`, mais un raccourci
     * de conversation sans catégorie est refusé par certaines surfaces.
     */
    private const val SHARE_CATEGORY = "fr.dtfh.messages.category.SHARE_TARGET"
}
