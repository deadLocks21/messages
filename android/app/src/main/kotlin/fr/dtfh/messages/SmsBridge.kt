package fr.dtfh.messages

import android.app.Activity
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val store = SmsStore(activity)

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
        }
    }

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        val filter = IntentFilter().apply {
            addAction(SmsStore.ACTION_SMS_SENT)
            addAction(SmsStore.ACTION_SMS_DELIVERED)
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
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) =
        SmsEventBus.attach(events)

    override fun onCancel(arguments: Any?) = SmsEventBus.detach()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
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
                    store.markThreadRead(call.argument<String>("threadId")!!)
                    SmsEventBus.emitChanged()
                    result.success(null)
                }

                "deleteThread" -> {
                    requireDefaultSmsApp()
                    store.deleteThread(call.argument<String>("threadId")!!)
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
                        subscriptionId = call.argument<Int>("subscriptionId"),
                    )
                    SmsEventBus.emitChanged()
                    result.success(message)
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

                "checkAccess" -> result.success(access())

                "requestDefaultSmsApp" -> requestDefaultSmsApp(result)

                else -> result.notImplemented()
            }
        } catch (e: NotDefaultSmsAppException) {
            result.error("not_default_sms_app", e.message, null)
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

        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            roleManager?.createRequestRoleIntent(RoleManager.ROLE_SMS)
        } else {
            @Suppress("DEPRECATION")
            Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).putExtra(
                Telephony.Sms.Intents.EXTRA_PACKAGE_NAME,
                activity.packageName,
            )
        }

        if (intent == null) {
            pendingRoleResult = null
            result.success(access())
            return
        }
        activity.startActivityForResult(intent, ROLE_REQUEST_CODE)
    }

    private fun isDefaultSmsApp(): Boolean =
        Telephony.Sms.getDefaultSmsPackage(activity) == activity.packageName

    private fun granted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun access(): Map<String, Any?> = mapOf(
        "canReadSms" to granted(android.Manifest.permission.READ_SMS),
        "canSendSms" to granted(android.Manifest.permission.SEND_SMS),
        "canReadContacts" to granted(android.Manifest.permission.READ_CONTACTS),
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
