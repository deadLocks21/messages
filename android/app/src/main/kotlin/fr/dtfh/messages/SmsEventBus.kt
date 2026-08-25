package fr.dtfh.messages

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Point de passage unique des événements natifs vers Dart.
 *
 * Les récepteurs (`SmsDeliverReceiver`, accusés d'envoi) peuvent s'exécuter
 * alors qu'aucune UI n'est attachée : dans ce cas il n'y a pas de `sink`, et
 * l'événement est simplement perdu — Dart rechargera ses vues au retour au
 * premier plan (`AppLifecycleState.resumed`). C'est volontaire : bufferiser
 * indéfiniment ferait rejouer un historique à la réouverture.
 *
 * `EventChannel.EventSink` n'est utilisable que depuis le thread principal ;
 * tous les envois y sont donc reportés.
 */
object SmsEventBus {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink?) {
        this.sink = sink
    }

    fun detach() {
        sink = null
    }

    fun emit(event: Map<String, Any?>) {
        val target = sink ?: return
        main.post {
            // Le sink a pu être détaché entre-temps ; `runCatching` couvre aussi
            // le cas d'un canal déjà fermé.
            runCatching { target.success(event) }
        }
    }

    /** Un SMS vient d'être reçu et écrit dans le stock. */
    fun emitReceived(message: Map<String, Any?>) =
        emit(mapOf("type" to "received", "message" to message))

    /** Accusé de dépôt réseau ou de remise d'un message envoyé. */
    fun emitStatus(id: String, threadId: String, status: String) =
        emit(mapOf("type" to "status", "id" to id, "threadId" to threadId, "status" to status))

    /** Le stock a changé sans plus de détail (suppression, marquage lu…). */
    fun emitChanged() = emit(mapOf("type" to "changed"))
}
