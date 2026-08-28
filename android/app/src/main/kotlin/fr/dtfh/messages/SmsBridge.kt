package fr.dtfh.messages

import android.app.Activity
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.app.PendingIntent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Côté natif du canal `fr.dtfh.messages/sms`.
 *
 * Trois responsabilités :
 * 1. exposer [SmsStore] à Dart (fils, messages, envoi, suppression) ;
 * 2. porter la demande du rôle « application SMS par défaut », qui exige une
 *    `Activity` et un retour d'`onActivityResult` ;
 * 3. écouter les accusés d'envoi/remise et les republier vers Dart.
 *
 * Les codes d'erreur rendus (`not_default_sms_app`, `permission_denied`,
 * `not_found`) sont ceux que `AndroidSmsChannel` traduit en exceptions du
 * domaine.
 */
class SmsBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "fr.dtfh.messages/sms"
        const val EVENT_CHANNEL = "fr.dtfh.messages/sms_events"
        const val ROLE_REQUEST_CODE = 4711

        /**
         * L'accusé que le service MMS du système rendra une fois le PDU déposé
         * auprès du MMSC.
         *
         * Le MMS n'a pas d'accusé de remise séparé comme le SMS : le dépôt est
         * le seul retour, et il arrive par ce `PendingIntent` que
         * [MmsStore.sendMessage] confie à `sendMultimediaMessage`.
         */
        fun mmsSentIntent(
            context: Context,
            messageId: String,
            threadId: String,
        ): PendingIntent {
            val intent = Intent(MmsStore.ACTION_MMS_SENT).apply {
                setPackage(context.packageName)
                putExtra(SmsStore.EXTRA_MESSAGE_ID, messageId)
                putExtra(SmsStore.EXTRA_THREAD_ID, threadId)
            }
            return PendingIntent.getBroadcast(
                context,
                (messageId + MmsStore.ACTION_MMS_SENT).hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val store = SmsStore(activity)
    private val picker = AttachmentPicker(activity)

    /**
     * Où s'exécutent les accès au stock.
     *
     * Un `MethodCallHandler` est appelé sur le fil principal d'Android. Or
     * parcourir `content://sms` et `content://mms` prend, sur un stock réel,
     * de l'ordre de la seconde : tant que ça dure, l'application ne peut plus
     * livrer une seule frame. Le symptôme n'est pas un rendu lent — les frames
     * restent courtes à construire — mais des frames livrées avec des
     * centaines de millisecondes de retard, ce qui se voit surtout aux
     * transitions d'écran.
     *
     * **Un seul thread**, pas un pool : le provider est de toute façon
     * sérialisé, et plusieurs parcours concurrents ne feraient que se disputer
     * le même verrou en multipliant les curseurs ouverts. Ce fil unique garde
     * aussi l'ordre des écritures, ce dont dépend la cohérence du stock.
     */
    private val storeExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "sms-store")
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Les appels qui doivent rester sur le fil principal : ils lancent une
     * `Activity` ou lisent son état, ce qu'on ne fait pas d'ailleurs. Ils sont
     * tous immédiats — aucun ne touche le provider.
     */
    private val mainThreadMethods = setOf(
        "pickAttachments",
        "requestDefaultSmsApp",
        "consumeLaunchRequest",
        "checkAccess",
    )

    /** Résultat en attente de la boîte de dialogue de rôle. */
    private var pendingRoleResult: MethodChannel.Result? = null

    /**
     * Demande de rédaction ayant lancé l'app (notification touchée, lien `sms:`
     * d'un navigateur, partage d'une autre application). Consommée une seule
     * fois par Dart, pour qu'un rebuild ne rejoue pas la navigation.
     */
    private var launchRequest: Map<String, Any?>? = parseComposeIntent(activity.intent)

    /** Accusés d'envoi et de remise, publiés par [SmsStore] via PendingIntent. */
    private val sendStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val messageId = intent.getStringExtra(SmsStore.EXTRA_MESSAGE_ID) ?: return
            val threadId = intent.getStringExtra(SmsStore.EXTRA_THREAD_ID).orEmpty()
            val delivered = intent.action == SmsStore.ACTION_SMS_DELIVERED
            val success = resultCode == Activity.RESULT_OK
            val status = runCatching {
                store.applySendResult(messageId, delivered = delivered, success = success)
            }.getOrDefault(if (success) "sent" else "failed")
            SmsEventBus.emitStatus(messageId, threadId, status)
            // Le stock a changé de forme, pas seulement d'état : un MMS passé
            // en « envoyé » sort de la boîte d'envoi.
            if (MmsStore.isMmsId(messageId)) SmsEventBus.emitChanged()
        }
    }

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        val filter = IntentFilter().apply {
            addAction(SmsStore.ACTION_SMS_SENT)
            addAction(SmsStore.ACTION_SMS_DELIVERED)
            addAction(MmsStore.ACTION_MMS_SENT)
        }
        ContextCompat.registerReceiver(
            activity,
            sendStatusReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    fun detach() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        SmsEventBus.detach()
        runCatching { activity.unregisterReceiver(sendStatusReceiver) }
        storeExecutor.shutdown()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) =
        SmsEventBus.attach(events)

    override fun onCancel(arguments: Any?) = SmsEventBus.detach()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method in mainThreadMethods) {
            handle(call, result)
            return
        }
        storeExecutor.execute { handle(call, MainThreadResult(result, mainHandler)) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listConversations" -> result.success(store.listConversations())

                "getConversation" -> result.success(
                    store.getConversation(call.argument<String>("threadId")!!)
                )

                "resolveThreadId" -> result.success(
                    store.resolveThreadId(call.argument<List<String>>("recipients")!!)
                )

                "markThreadRead" -> {
                    requireDefaultSmsApp()
                    val threadId = call.argument<String>("threadId")!!
                    val updated = store.markThreadRead(threadId)
                    // Lire le fil dans l'app rend sa notification caduque.
                    SmsNotifications.cancel(activity, threadId)
                    // Un fil déjà lu n'a rien changé au stock : publier un
                    // événement ferait recharger toutes les vues pour rien,
                    // justement pendant l'ouverture du fil.
                    if (updated > 0) SmsEventBus.emitChanged()
                    result.success(updated > 0)
                }

                "deleteThread" -> {
                    requireDefaultSmsApp()
                    val threadId = call.argument<String>("threadId")!!
                    store.deleteThread(threadId)
                    SmsNotifications.cancel(activity, threadId)
                    SmsEventBus.emitChanged()
                    result.success(null)
                }

                "listMessages" -> result.success(
                    store.listMessages(
                        call.argument<String>("threadId")!!,
                        call.argument<Int>("limit") ?: 500,
                    )
                )

                "searchMessages" -> result.success(
                    store.searchMessages(
                        call.argument<String>("query")!!,
                        call.argument<Int>("limit") ?: 50,
                    )
                )

                "getMessage" -> result.success(store.getMessage(call.argument<String>("id")!!))

                "sendMessage" -> {
                    requireDefaultSmsApp()
                    val message = store.sendMessage(
                        recipients = call.argument<List<String>>("recipients")!!,
                        body = call.argument<String>("body")!!,
                        attachments = call.argument<List<Map<String, Any?>>>(
                            "attachments"
                        ) ?: emptyList(),
                        subscriptionId = call.argument<Int>("subscriptionId"),
                    )
                    SmsEventBus.emitChanged()
                    result.success(message)
                }

                "pickAttachments" ->
                    picker.pick(call.argument<String>("source")!!, result)

                "readAttachment" ->
                    result.success(store.readAttachment(call.argument<String>("id")!!))

                "openAttachment" -> {
                    // La copie est de l'entrée-sortie, elle reste sur ce
                    // fil-ci ; le lancement d'une activité, lui, ne se fait que
                    // depuis le fil principal.
                    val staged = AttachmentOpener.stage(
                        activity,
                        call.argument<String>("id")!!,
                        call.argument<String>("fileName"),
                    )
                    if (staged == null) {
                        result.success(false)
                        return
                    }
                    val mimeType = call.argument<String>("mimeType").orEmpty()
                    mainHandler.post {
                        result.success(AttachmentOpener.view(activity, staged, mimeType))
                    }
                }

                "readAttachmentUri" ->
                    result.success(store.readUri(call.argument<String>("uri")!!))

                "discardAttachment" -> {
                    discard(activity, Uri.parse(call.argument<String>("uri")!!))
                    result.success(null)
                }

                "mmsMaxMessageSize" -> result.success(MmsConfig.maxMessageSize(activity))

                "compressAttachment" -> {
                    val mimeType = call.argument<String>("mimeType").orEmpty()
                    // Seules les images se rééchantillonnent. Une vidéo
                    // demanderait un ré-encodage complet, un PDF n'a rien de
                    // superflu à jeter : le refus est franc.
                    if (!mimeType.startsWith("image/")) {
                        result.success(null)
                        return
                    }
                    result.success(
                        ImageCompressor.compress(
                            activity,
                            Uri.parse(call.argument<String>("uri")!!),
                            call.argument<Int>("targetBytes")!!,
                        )
                    )
                }

                "deleteMessage" -> {
                    requireDefaultSmsApp()
                    val deleted = store.deleteMessage(call.argument<String>("id")!!)
                    if (deleted == 0) {
                        result.error("not_found", "Message introuvable", null)
                        return
                    }
                    SmsEventBus.emitChanged()
                    result.success(null)
                }

                "consumeLaunchRequest" -> {
                    result.success(launchRequest)
                    launchRequest = null
                }

                "setMutedThreads" -> {
                    NotificationSettings.setMutedThreads(
                        activity,
                        call.argument<List<String>>("threadIds")!!.toSet(),
                    )
                    result.success(null)
                }

                "setNotificationDirectory" -> {
                    NotificationSettings.setDirectory(
                        activity,
                        call.argument<Map<String, String>>("names")!!,
                    )
                    result.success(null)
                }

                "checkAccess" -> result.success(access())

                "requestDefaultSmsApp" -> requestDefaultSmsApp(result)

                else -> result.notImplemented()
            }
        } catch (e: NotDefaultSmsAppException) {
            result.error("not_default_sms_app", e.message, null)
        } catch (e: AttachmentUnavailableException) {
            result.error("attachment_unavailable", e.message, null)
        } catch (e: SecurityException) {
            result.error("permission_denied", e.message, null)
        } catch (e: Exception) {
            result.error("sms_error", e.message, null)
        }
    }

    /**
     * Nouvel intent alors que l'app tourne déjà (`launchMode="singleTop"`) :
     * typiquement l'appui sur une notification de SMS reçu.
     */
    fun onNewIntent(intent: Intent) {
        val request = parseComposeIntent(intent) ?: return
        SmsEventBus.emit(request)
    }

    /**
     * Extrait le destinataire et le corps d'un intent `sms:` / `smsto:`.
     *
     * `sms:0612345678?body=…` place le numéro dans la partie spécifique au
     * schéma ; le corps arrive selon les émetteurs par `sms_body` (convention
     * Android) ou `EXTRA_TEXT` (partage générique).
     */
    private fun parseComposeIntent(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        if (intent.action !in
            setOf(Intent.ACTION_VIEW, Intent.ACTION_SENDTO, Intent.ACTION_SEND)
        ) {
            return null
        }

        val data = intent.data
        val address = data
            ?.takeIf { it.scheme in setOf("sms", "smsto", "mms", "mmsto") }
            ?.schemeSpecificPart
            ?.substringBefore('?')
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        val body = intent.getStringExtra("sms_body")
            ?: intent.getStringExtra(Intent.EXTRA_TEXT)

        if (address == null && body.isNullOrEmpty()) return null
        return mapOf("type" to "compose", "address" to address, "body" to body)
    }

    /** Relaie l'issue de la boîte de dialogue de rôle vers l'appel Dart en attente. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (picker.onActivityResult(requestCode, resultCode, data)) return true
        if (requestCode != ROLE_REQUEST_CODE) return false
        // On ne se fie pas au `resultCode` : sur certains OEM il vaut CANCELED
        // alors que le rôle a bien été accordé. La seule vérité est l'état du
        // paquet par défaut.
        pendingRoleResult?.success(access())
        pendingRoleResult = null
        return true
    }

    private fun requestDefaultSmsApp(result: MethodChannel.Result) {
        if (isDefaultSmsApp()) {
            result.success(access())
            return
        }
        // Une seule demande à la fois : la précédente est close avec l'état
        // courant plutôt que laissée en suspens côté Dart.
        pendingRoleResult?.success(access())
        pendingRoleResult = result

        activity.startActivityForResult(roleRequestIntent(), ROLE_REQUEST_CODE)
    }

    /**
     * Comment demander le rôle : `RoleManager` depuis Android 10, sinon
     * l'intent historique. Un appareil sans téléphonie n'expose pas `ROLE_SMS`
     * — on retombe alors aussi sur l'intent, qui sait refuser proprement.
     */
    private fun roleRequestIntent(): Intent {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                return roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
            }
        }
        @Suppress("DEPRECATION")
        return Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).putExtra(
            Telephony.Sms.Intents.EXTRA_PACKAGE_NAME,
            activity.packageName,
        )
    }

    /**
     * L'app tient-elle le rôle SMS ?
     *
     * `getDefaultSmsPackage()` lit `Settings.Secure.SMS_DEFAULT_APPLICATION`,
     * que `RoleManager` met à jour de façon **asynchrone** : juste après la
     * boîte de dialogue de rôle, il désigne encore l'application précédente. On
     * a donc pu répondre « non » à Dart alors que le rôle venait d'être accordé
     * — d'où un bandeau « définissez Messages par défaut » qui ne partait plus.
     *
     * Depuis Android 10, `isRoleHeld` est la source de vérité et se met à jour
     * avec le rôle. Les deux signaux sont **positifs** : l'un ou l'autre suffit,
     * un désaccord voulant seulement dire que le plus lent n'a pas rattrapé.
     */
    private fun isDefaultSmsApp(): Boolean {
        val byPackage =
            Telephony.Sms.getDefaultSmsPackage(activity) == activity.packageName
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return byPackage

        val roleManager = activity.getSystemService(RoleManager::class.java)
            ?: return byPackage
        val byRole = runCatching {
            roleManager.isRoleHeld(RoleManager.ROLE_SMS)
        }.getOrDefault(false)
        return byPackage || byRole
    }

    private fun granted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun access(): Map<String, Any?> = mapOf(
        "canReadSms" to granted(android.Manifest.permission.READ_SMS),
        "canSendSms" to granted(android.Manifest.permission.SEND_SMS),
        "canReadContacts" to granted(android.Manifest.permission.READ_CONTACTS),
        // `areNotificationsEnabled` couvre d'un coup la permission runtime
        // (API 33+) et la désactivation depuis les réglages système, qui ne
        // passe par aucune permission.
        "canNotify" to NotificationManagerCompat.from(activity).areNotificationsEnabled(),
        "isDefaultSmsApp" to isDefaultSmsApp(),
    )

    /**
     * Android refuse silencieusement toute écriture du stock à une app qui n'a
     * pas le rôle : mieux vaut une erreur explicite qu'un message qui disparaît.
     */
    private fun requireDefaultSmsApp() {
        if (!isDefaultSmsApp()) throw NotDefaultSmsAppException()
    }
}

class NotDefaultSmsAppException :
    IllegalStateException("Messages n'est pas l'application SMS par défaut")


/**
 * Renvoie la réponse d'un appel sur le fil principal.
 *
 * `MethodChannel.Result` n'est utilisable que depuis lui, alors que le travail
 * a lieu sur [SmsBridge.storeExecutor].
 */
private class MainThreadResult(
    private val delegate: MethodChannel.Result,
    private val main: Handler,
) : MethodChannel.Result {

    override fun success(result: Any?) = main.post { delegate.success(result) }.let {}

    override fun error(code: String, message: String?, details: Any?) =
        main.post { delegate.error(code, message, details) }.let {}

    override fun notImplemented() = main.post { delegate.notImplemented() }.let {}
}
