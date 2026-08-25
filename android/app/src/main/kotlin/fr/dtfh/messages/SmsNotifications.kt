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
 * Notifications de SMS entrants.
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
 */
object SmsNotifications {
    private const val CHANNEL_ID = "sms"
    private const val CHANNEL_NAME = "Messages SMS"
    private const val GROUP_KEY = "fr.dtfh.messages.SMS"
    private const val SUMMARY_ID = 1

    /** Nombre de messages repris dans le fil de la notification. */
    private const val HISTORY = 6

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

    fun cancel(context: Context, threadId: String) {
        val manager = NotificationManagerCompat.from(context)
        manager.cancel(threadId, threadId.hashCode())
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
        val history = runCatching { SmsStore(context).listMessages(threadId, HISTORY) }
            .getOrDefault(emptyList())

        if (history.isEmpty() && body != null) {
            // Le stock n'a pas encore rendu le message (cas limite) : on affiche
            // au moins celui qu'on vient de recevoir.
            style.addMessage(body, timestamp, sender)
        } else {
            for (message in history) {
                val outgoing = message["direction"] == "outgoing"
                style.addMessage(
                    message["body"] as? String ?: "",
                    message["date"] as? Long ?: 0L,
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
            manager.activeNotifications.count { it.id != SUMMARY_ID && it.tag != except }
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
}
