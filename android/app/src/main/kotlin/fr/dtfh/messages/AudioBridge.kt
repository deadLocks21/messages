package fr.dtfh.messages

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Côté natif du canal `fr.dtfh.messages/audio` : l'écoute des vocaux.
 *
 * Un canal à part de [SmsBridge], et non une poignée de méthodes ajoutées au
 * sien : celui-ci parle au `ContentProvider` sur un fil dédié, alors qu'un
 * `MediaPlayer` vit sur le fil principal — c'est là que son `Looper` livre les
 * rappels de préparation et de fin.
 *
 * **Un seul lecteur.** Lancer un vocal libère celui d'avant : deux sons
 * superposés ne s'écoutent pas, et c'est aussi ce que promet le port
 * `AudioPlayerService`.
 *
 * La position n'est pas calculée, elle est **lue** dans le lecteur toutes les
 * [TICK_MS] millisecondes et poussée vers Dart. Une horloge côté Dart dériverait
 * de la lecture réelle.
 */
class AudioBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "fr.dtfh.messages/audio"
        const val EVENT_CHANNEL = "fr.dtfh.messages/audio_events"

        /** Cadence de publication de la position. */
        private const val TICK_MS = 100L
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val handler = Handler(Looper.getMainLooper())

    /**
     * Où se mesurent les formes d'onde.
     *
     * Tout le reste de ce pont est immédiat et tient sur le fil principal — un
     * `MediaPlayer` y vit de toute façon. Décoder un vocal entier, non : c'est
     * l'affaire de quelques centaines de millisecondes, pendant lesquelles
     * aucune frame ne serait livrée. **Un seul thread**, pour que dix bulles
     * qui apparaissent d'un coup se mesurent l'une après l'autre plutôt que de
     * se disputer les décodeurs du système.
     */
    private val waveformExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "audio-waveform")
    }

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    /**
     * Un vocal est de la parole, pas de la musique : l'annoncer permet au
     * système de router le son correctement et de ne pas l'écraser d'effets.
     */
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private var player: MediaPlayer? = null
    private var currentId: String? = null

    /** `currentPosition` et `duration` lèvent tant que la préparation n'est pas finie. */
    private var prepared = false

    private var events: EventChannel.EventSink? = null
    private var focusRequest: AudioFocusRequest? = null

    private val ticker = object : Runnable {
        override fun run() {
            emit()
            handler.postDelayed(this, TICK_MS)
        }
    }

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun detach() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        release()
        events = null
        waveformExecutor.shutdown()
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
        emit()
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                play(call.argument<String>("id")!!)
                result.success(null)
            }

            "pause" -> {
                pause()
                result.success(null)
            }

            "seek" -> {
                seek(
                    call.argument<String>("id")!!,
                    call.argument<Int>("positionMs") ?: 0,
                )
                result.success(null)
            }

            "stop" -> {
                release()
                emit()
                result.success(null)
            }

            "waveform" -> {
                val id = call.argument<String>("id")!!
                val buckets = call.argument<Int>("buckets") ?: 64
                waveformExecutor.execute {
                    val levels = AudioWaveform.of(context, id, buckets)
                    handler.post { result.success(levels) }
                }
            }

            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------- lecture

    private fun play(attachmentId: String) {
        // Reprise : le lecteur est déjà ouvert sur cette partie, il garde sa
        // position — celle d'une pause, ou celle qu'un déplacement a posée.
        // Rouvrir la remettrait à zéro.
        val existing = player
        if (existing != null && attachmentId == currentId && prepared) {
            requestFocus()
            existing.start()
            startTicking()
            emit()
            return
        }
        open(attachmentId, startWhenReady = true)
    }

    private fun pause() {
        val current = player ?: return
        if (!prepared) return
        runCatching { current.pause() }
        stopTicking()
        abandonFocus()
        emit()
    }

    private fun seek(attachmentId: String, positionMs: Int) {
        val current = player
        if (current != null && attachmentId == currentId && prepared) {
            runCatching { current.seekTo(positionMs.coerceIn(0, current.duration)) }
            emit()
            return
        }
        // Viser un point d'un vocal qui n'est pas chargé l'ouvre — et l'attend
        // là, sans le lancer.
        open(attachmentId, startWhenReady = false, seekToMs = positionMs)
    }

    /**
     * Ouvre une partie dans un lecteur neuf, et selon le cas la lance ou la
     * pose à [seekToMs].
     */
    private fun open(
        attachmentId: String,
        startWhenReady: Boolean,
        seekToMs: Int? = null,
    ) {
        release()
        currentId = attachmentId

        val created = MediaPlayer().apply {
            setAudioAttributes(attributes)
            setOnPreparedListener {
                prepared = true
                if (seekToMs != null) {
                    runCatching { it.seekTo(seekToMs.coerceIn(0, it.duration)) }
                }
                if (startWhenReady) {
                    requestFocus()
                    it.start()
                    startTicking()
                }
                emit()
            }
            setOnCompletionListener { finish() }
            // Une partie effacée du stock, un format que l'appareil ne décode
            // pas : la bulle doit retrouver son bouton « lire », pas rester en
            // lecture perpétuelle. `true` : l'erreur est traitée ici.
            setOnErrorListener { _, _, _ ->
                finish()
                true
            }
        }
        player = created

        val opened = runCatching {
            created.setDataSource(context, MmsStore.partUri(attachmentId))
            created.prepareAsync()
        }.isSuccess
        if (!opened) finish() else emit()
    }

    /** Fin de lecture ou échec : le lecteur disparaît, l'état redevient vide. */
    private fun finish() {
        release()
        emit()
    }

    private fun release() {
        stopTicking()
        abandonFocus()
        player?.let { current ->
            runCatching { current.stop() }
            current.release()
        }
        player = null
        currentId = null
        prepared = false
    }

    private fun startTicking() {
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, TICK_MS)
    }

    private fun stopTicking() = handler.removeCallbacks(ticker)

    private fun emit() {
        val sink = events ?: return
        val current = player
        val id = currentId
        if (current == null || id == null || !prepared) {
            // Pas encore prêt : annoncer la pièce jointe sans durée suffit à ce
            // que la bulle montre qu'il se passe quelque chose.
            sink.success(
                if (id == null) emptyMap<String, Any?>() else mapOf(
                    "attachmentId" to id,
                    "positionMs" to 0,
                    "durationMs" to 0,
                    "isPlaying" to false,
                )
            )
            return
        }
        sink.success(
            mapOf(
                "attachmentId" to id,
                "positionMs" to current.currentPosition,
                // Un flux dont la durée est inconnue rend -1 : mieux vaut zéro,
                // que la bulle sait interpréter.
                "durationMs" to current.duration.coerceAtLeast(0),
                "isPlaying" to current.isPlaying,
            )
        )
    }

    // --------------------------------------------------------------- focus

    /**
     * Demande le silence aux autres : écouter un vocal par-dessus de la musique
     * ne s'entend pas. Best effort — un refus n'empêche pas la lecture, il ne
     * fait que la rendre moins confortable.
     *
     * `AudioFocusRequest` n'existe qu'à partir d'Android 8. En dessous, le
     * `minSdk` de l'app oblige à s'en passer plutôt qu'à appeler une API
     * dépréciée.
     */
    private fun requestFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener { change ->
                // Un appel entrant, une autre app qui prend la parole : on
                // suspend, on ne reprend pas tout seul.
                if (change == AudioManager.AUDIOFOCUS_LOSS ||
                    change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                ) {
                    pause()
                }
            }
            .build()
        focusRequest = request
        runCatching { audioManager.requestAudioFocus(request) }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        focusRequest?.let { runCatching { audioManager.abandonAudioFocusRequest(it) } }
        focusRequest = null
    }
}
