package fr.dtfh.messages

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput

/**
 * Notifications de la messagerie : les SMS entrants, et les envois que le
 * réseau a refusés.
 *
 * Une application SMS par défaut est seule responsable de prévenir
 * l'utilisateur : le système ne notifie plus rien à sa place.
 *
 * Une notification par fil (le `thread_id` sert de tag), au style
 * `MessagingStyle` — celui que le système réserve aux conversations : il affiche
 * les derniers échanges, l'avatar de l'interlocuteur, et alimente les bulles de
 * conversation d'Android 11+. Les messages affichés sont **relus du stock** au
 * moment de notifier plutôt que mémorisés ici : le provider est déjà la source
 * de vérité, inutile d'en tenir une copie.
 *
 * Le fil affiché s'arrête à l'**ancre** du fil — la date du message qui a ouvert
 * la salve en cours. Rejouer dans le volet des échanges déjà lus n'apprend rien
 * à l'utilisateur, et noie le message qui vient d'arriver.
 */
object SmsNotifications {
    private const val CHANNEL_ID = "sms"
    private const val CHANNEL_NAME = "Messages SMS"

    /**
     * Un échec d'envoi ne se range pas avec les messages reçus : ce n'est pas
     * la même urgence, et l'utilisateur doit pouvoir couper l'un sans l'autre.
     * D'où un canal séparé, que le système présente sous son propre nom dans
     * les réglages.
     */
    private const val FAILURE_CHANNEL_ID = "send_failures"
    private const val FAILURE_CHANNEL_NAME = "Échecs d'envoi"

    /**
     * Préfixe du tag des notifications d'échec : elles portent le même
     * `thread_id` que celle du fil, mais ne disent pas la même chose et ne
     * doivent pas se remplacer l'une l'autre.
     */
    private const val FAILURE_TAG = "send-failure:"

    private const val GROUP_KEY = "fr.dtfh.messages.SMS"
    private const val SUMMARY_ID = 1

    /** Préférences natives où survit l'ancre de chaque fil. */
    private const val ANCHOR_PREFS = "fr.dtfh.messages.notification_anchors"

    /**
     * Plafond de messages relus du stock. Ce n'est pas le nombre affiché — seuls
     * ceux postérieurs à l'ancre le sont — mais une borne à la requête.
     */
    private const val MAX_HISTORY = 25

    /** Clé du texte saisi dans la réponse directe. */
    const val REMOTE_INPUT_KEY = "reply_text"

    /** Notifie un message reçu — avec son et vibration. */
    fun notifyIncoming(
        context: Context,
        threadId: String,
        address: String,
        body: String,
        timestamp: Long,
    ) = notify(context, threadId, address, body, timestamp, alert = true)

    /**
     * Reconstruit la notification d'un fil après une réponse directe : la
     * réponse apparaît dans le fil, mais **sans réalerter** — l'utilisateur
     * vient d'agir, le resonner serait absurde.
     */
    fun refreshAfterReply(context: Context, threadId: String, address: String) =
        notify(context, threadId, address, body = null, timestamp = 0, alert = false)

    /**
     * Prévient que le message n'est pas parti.
     *
     * C'est le pendant de la bulle « Non distribué » pour l'utilisateur qui a
     * quitté l'écran : l'envoi d'un SMS se joue après coup, et sans cette
     * notification un message resté au sol ne se découvre qu'en rouvrant le
     * fil, parfois des heures plus tard.
     *
     * La sourdine du fil n'est **pas** consultée : elle dit « ne me préviens
     * pas de ce que cette personne m'écrit », pas « ne me préviens pas quand
     * ce que je lui écris n'arrive pas ».
     */
    fun notifySendFailure(
        context: Context,
        threadId: String,
        address: String,
        body: String,
    ) {
        ensureFailureChannel(context)

        val name = NotificationSettings.nameFor(context, address) ?: address
        val builder = NotificationCompat.Builder(context, FAILURE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("Message non envoyé")
            .setContentText(name.ifBlank { "Touchez pour réessayer" })
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_ERROR)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            // Le fil s'ouvre sur le message en échec, où l'appui long propose
            // « Réessayer » : la notification mène là où on répare, elle ne se
            // contente pas d'annoncer.
            .setContentIntent(openThreadIntent(context, threadId, address))

        runCatching {
            NotificationManagerCompat.from(context)
                .notify(FAILURE_TAG + threadId, threadId.hashCode(), builder.build())
        }
    }

    fun cancel(context: Context, threadId: String) {
        val manager = NotificationManagerCompat.from(context)
        manager.cancel(threadId, threadId.hashCode())
        // Le fil vient d'être lu : l'échec y est visible sur la bulle, la
        // notification n'a plus rien à apprendre à personne.
        manager.cancel(FAILURE_TAG + threadId, threadId.hashCode())
        clearAnchor(context, threadId)
        // Le résumé ne doit pas survivre seul à la dernière notification du
        // groupe : Android le laisserait affiché, vide. `cancel` étant
        // asynchrone, on exclut explicitement le fil qu'on vient de retirer
        // plutôt que d'espérer qu'il ait déjà disparu du décompte.
        if (activeThreadNotifications(context, except = threadId) == 0) {
            manager.cancel(SUMMARY_ID)
        }
    }

    private fun notify(
        context: Context,
        threadId: String,
        address: String,
        body: String?,
        timestamp: Long,
        alert: Boolean,
    ) {
        // Fil en sourdine : le message est écrit dans le stock, mais rien ne
        // vient déranger l'utilisateur.
        if (NotificationSettings.isMuted(context, threadId)) return

        ensureChannel(context)

        val name = NotificationSettings.nameFor(context, address) ?: address
        val sender = Person.Builder().setName(name).setKey(address).build()
        val me = Person.Builder().setName("Moi").build()

        val style = NotificationCompat.MessagingStyle(me)
        val history = runCatching { SmsStore(context).listMessages(threadId, MAX_HISTORY) }
            .getOrDefault(emptyList())
        val anchor = resolveAnchor(context, threadId, history, timestamp)
        val shown = history.filter { dateOf(it) >= anchor }

        if (shown.isEmpty() && body != null) {
            // Le stock n'a pas encore rendu le message (cas limite) : on affiche
            // au moins celui qu'on vient de recevoir.
            style.addMessage(body, timestamp, sender)
        } else {
            for (message in shown) {
                val outgoing = message["direction"] == "outgoing"
                style.addMessage(
                    message["body"] as? String ?: "",
                    dateOf(message),
                    if (outgoing) null else sender,
                )
            }
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setStyle(style)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setGroup(GROUP_KEY)
            .setOnlyAlertOnce(!alert)
            .setContentIntent(openThreadIntent(context, threadId, address))
            .addAction(replyAction(context, threadId, address))
            .addAction(markReadAction(context, threadId))

        if (alert) builder.setDefaults(NotificationCompat.DEFAULT_ALL)

        // POST_NOTIFICATIONS peut être refusée (API 33+) : on ne fait pas tomber
        // la réception pour autant, le message est déjà dans le stock.
        runCatching {
            val manager = NotificationManagerCompat.from(context)
            manager.notify(threadId, threadId.hashCode(), builder.build())
            manager.notify(SUMMARY_ID, summary(context))
        }
    }

    /**
     * Date du message qui a ouvert la salve en cours, et donc début du fil
     * affiché. Elle survit dans un `SharedPreferences` parce que le process meurt
     * entre deux SMS.
     *
     * Elle est reposée dès qu'aucune notification n'est affichée pour le fil :
     * balayée, ouverte, ou marquée comme lue, peu importe — la salve suivante
     * repart du message qui l'ouvre. C'est l'état affiché qui fait foi, pas le
     * drapeau `read` du provider : une notification balayée sans être lue ne doit
     * pas ressortir au message suivant.
     */
    private fun resolveAnchor(
        context: Context,
        threadId: String,
        history: List<Map<String, Any?>>,
        timestamp: Long,
    ): Long {
        val prefs = context.getSharedPreferences(ANCHOR_PREFS, Context.MODE_PRIVATE)
        val stored = prefs.getLong(threadId, 0L)
        if (stored != 0L && isShowing(context, threadId)) return stored

        // Nouvelle salve. `timestamp` vaut 0 lors d'un simple rafraîchissement
        // (réponse directe) : l'ancre est alors le dernier entrant, pour que la
        // notification garde le message auquel on vient de répondre.
        val fresh = if (timestamp > 0) {
            timestamp
        } else {
            history.lastOrNull { it["direction"] == "incoming" }?.let { dateOf(it) } ?: 0L
        }
        prefs.edit().putLong(threadId, fresh).apply()
        return fresh
    }

    private fun clearAnchor(context: Context, threadId: String) {
        context.getSharedPreferences(ANCHOR_PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(threadId)
            .apply()
    }

    /** Une notification est-elle actuellement affichée pour ce fil ? */
    private fun isShowing(context: Context, threadId: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        return runCatching {
            manager.activeNotifications.any { it.tag == threadId }
        }.getOrDefault(false)
    }

    private fun dateOf(message: Map<String, Any?>): Long = message["date"] as? Long ?: 0L

    /**
     * Résumé du groupe : ce qu'affiche Android quand plusieurs fils notifient en
     * même temps. Il porte un titre — un résumé vide s'affiche comme une
     * notification blanche sur certaines surfaces.
     */
    private fun summary(context: Context) =
        NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle("Messages")
            .setStyle(NotificationCompat.InboxStyle().setSummaryText("Nouveaux messages"))
            .setGroup(GROUP_KEY)
            .setGroupSummary(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .build()

    private fun activeThreadNotifications(context: Context, except: String): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return 0
        val manager = context.getSystemService(NotificationManager::class.java) ?: return 0
        return runCatching {
            manager.activeNotifications.count {
                // Un échec d'envoi n'appartient pas au groupe des messages
                // reçus : le compter ferait survivre leur résumé à lui seul.
                it.id != SUMMARY_ID &&
                    it.tag != except &&
                    it.tag?.startsWith(FAILURE_TAG) != true
            }
        }.getOrDefault(0)
    }

    /** Ouvre l'app sur le fil concerné (même chemin qu'un lien `sms:`). */
    private fun openThreadIntent(
        context: Context,
        threadId: String,
        address: String,
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("sms:$address")).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context,
            threadId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun replyAction(
        context: Context,
        threadId: String,
        address: String,
    ): NotificationCompat.Action {
        val remoteInput = RemoteInput.Builder(REMOTE_INPUT_KEY)
            .setLabel("Répondre")
            .build()

        // MUTABLE : le système doit pouvoir injecter le texte saisi dans
        // l'intent. C'est l'exception admise à FLAG_IMMUTABLE.
        val pending = PendingIntent.getBroadcast(
            context,
            ("reply$threadId").hashCode(),
            NotificationActionReceiver.replyIntent(context, threadId, address),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

        return NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            "Répondre",
            pending,
        )
            .addRemoteInput(remoteInput)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setShowsUserInterface(false)
            .build()
    }

    private fun markReadAction(context: Context, threadId: String): NotificationCompat.Action {
        val pending = PendingIntent.getBroadcast(
            context,
            ("read$threadId").hashCode(),
            NotificationActionReceiver.markReadIntent(context, threadId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_view,
            "Marquer comme lu",
            pending,
        )
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ)
            .setShowsUserInterface(false)
            .build()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Nouveaux messages reçus"
                enableVibration(true)
            }
        )
    }

    private fun ensureFailureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(FAILURE_CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                FAILURE_CHANNEL_ID,
                FAILURE_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Messages que le réseau n'a pas acceptés"
                enableVibration(true)
            }
        )
    }
}
