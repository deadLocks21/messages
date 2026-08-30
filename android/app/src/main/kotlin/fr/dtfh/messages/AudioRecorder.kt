package fr.dtfh.messages

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.media.audiofx.NoiseSuppressor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.content.FileProvider
import java.io.File
import java.util.UUID
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Enregistrement d'un vocal : `MediaRecorder`, et le relevé de son niveau.
 *
 * ## Pourquoi de l'AMR-NB
 *
 * Parce que le message part en **MMS**. L'AMR-NB est le codec de parole du
 * cœur de la spécification MMS — celui qu'un téléphone d'en face saura lire
 * sans transcodage —, et son débit constant de 12,2 kbit/s est ce qui permet
 * de dire *avant* d'enregistrer combien de temps le vocal peut durer. Un AAC
 * de meilleure qualité tiendrait quatre fois moins de secondes dans le même
 * budget, et rien ne garantit qu'il soit lu à l'arrivée.
 *
 * ## Une voix, pas un enregistrement de salle
 *
 * La source est `VOICE_COMMUNICATION` : le système lui applique ses traitements
 * de parole — bruit de fond, écho, gain. C'est ce que le panneau annonce sous
 * « Suppression du bruit ». Là où l'appareil ne la sert pas, le micro nu prend
 * le relais et le panneau ne promet plus rien.
 *
 * ## Le niveau vient du micro, pas d'un compteur
 *
 * [MediaRecorder.getMaxAmplitude] rend le pic depuis le dernier appel : lu dix
 * fois par seconde, il donne exactement une barre de la piste. C'est le
 * pendant de la position de lecture d'[AudioBridge] — ce que dessine l'écran
 * est mesuré, jamais inventé.
 *
 * ## Le fichier vit dans le cache
 *
 * `cacheDir/voice/`, exposé par le `FileProvider` de l'app comme les photos
 * prises et les vCards : c'est sous cette forme que l'envoi du MMS saura le
 * relire, et le système reste libre d'y faire le ménage.
 */
class AudioRecorder(private val context: Context) {

    companion object {
        /** Cadence des relevés de niveau. Celle du curseur de lecture. */
        private const val TICK_MS = 100L

        /** Débit visé — celui sur lequel Dart borne la durée d'un vocal. */
        private const val BIT_RATE = 12_200
        private const val SAMPLING_RATE = 8_000

        /** Pic théorique rendu par `getMaxAmplitude`. */
        private const val MAX_AMPLITUDE = 32_767.0

        /**
         * Nombre de niveaux publiés.
         *
         * La piste n'en montre qu'une soixantaine, les plus récents : porter
         * dix minutes de relevés d'un bord à l'autre du canal, cent fois par
         * seconde, coûterait plus cher que l'enregistrement lui-même.
         */
        private const val KEPT_LEVELS = 96
    }

    /** Ce que le panneau reçoit à chaque relevé. */
    fun interface Listener {
        fun onState(state: Map<String, Any?>)
    }

    private val handler = Handler(Looper.getMainLooper())

    private var recorder: MediaRecorder? = null

    /** L'appareil traite-t-il le bruit de fond de cet enregistrement-ci ? */
    private var noiseSuppressed = false

    private var file: File? = null
    private var startedAt = 0L
    private var elapsedMs = 0

    /** Vrai entre `stop()` et la relève du fichier : il y a quelque chose à joindre. */
    private var finished = false

    private val levels = ArrayList<Double>()

    var listener: Listener? = null

    /** L'état du moment, pour un abonné qui arrive en cours de route. */
    fun publishCurrentState() = emit()

    private val ticker = object : Runnable {
        override fun run() {
            sample()
            handler.postDelayed(this, TICK_MS)
        }
    }

    /**
     * Ouvre le micro.
     *
     * [maxDurationMs] est la borne calculée par Dart depuis la limite MMS de
     * l'opérateur : elle est confiée au `MediaRecorder`, qui s'arrêtera de
     * lui-même. Compter côté Dart pour couper laisserait passer les quelques
     * dixièmes de seconde du trajet, et un fichier hors budget.
     *
     * @throws IllegalStateException si le micro n'est pas donné.
     */
    fun start(maxDurationMs: Int) {
        release(deleteFile = true)

        val directory = File(context.cacheDir, "voice").apply { mkdirs() }
        val target = File(directory, "VOICE_${UUID.randomUUID()}.amr")
        file = target
        levels.clear()
        elapsedMs = 0
        finished = false

        // `VOICE_COMMUNICATION` d'abord : c'est la source que le système
        // traite — suppression du bruit, écho, gain — et c'est elle qui donne
        // à un vocal la voix nette de l'app d'origine. Tous les appareils ne la
        // servent pas ; le micro nu prend alors le relais, et le panneau
        // n'annonce plus rien.
        val started = runCatching {
            open(target, MediaRecorder.AudioSource.VOICE_COMMUNICATION, maxDurationMs)
        }.recoverCatching {
            releaseRecorder()
            open(target, MediaRecorder.AudioSource.MIC, maxDurationMs)
            false
        }.getOrThrow()

        noiseSuppressed = started && hasNoiseSuppression()
        startedAt = SystemClock.elapsedRealtime()
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, TICK_MS)
        emit()
    }

    /** @return vrai si la source demandée est bien celle qui enregistre. */
    private fun open(target: File, source: Int, maxDurationMs: Int): Boolean {
        val created = newRecorder().apply {
            setAudioSource(source)
            setOutputFormat(MediaRecorder.OutputFormat.AMR_NB)
            setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
            setAudioChannels(1)
            setAudioSamplingRate(SAMPLING_RATE)
            setAudioEncodingBitRate(BIT_RATE)
            setOutputFile(target.absolutePath)
            if (maxDurationMs > 0) setMaxDuration(maxDurationMs)
            setOnInfoListener { _, what, _ ->
                // Le budget de l'opérateur est atteint : on referme, et le
                // panneau bascule de lui-même en relecture. Rien n'est perdu —
                // ce qui a été dit jusque-là est joignable.
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    stop()
                }
            }
            // Le micro peut être pris par un appel, ou l'encodeur refuser :
            // dans les deux cas il n'y aura pas d'enregistrement, et le
            // panneau doit redevenir vide plutôt que compter dans le vide.
            setOnErrorListener { _, _, _ -> abort() }
        }
        recorder = created
        created.prepare()
        created.start()
        return source == MediaRecorder.AudioSource.VOICE_COMMUNICATION
    }

    /**
     * Referme le micro. Sans effet si l'enregistrement s'est déjà arrêté tout
     * seul — la borne de durée atteinte, par exemple.
     */
    fun stop() {
        val current = recorder ?: return
        handler.removeCallbacks(ticker)
        elapsedMs = (SystemClock.elapsedRealtime() - startedAt).toInt()
        // `stop()` lève quand rien n'a encore été écrit (appui sur « stop »
        // dans la seconde qui suit le départ) : le fichier est alors
        // inutilisable, et c'est un abandon, pas une erreur.
        val written = runCatching { current.stop() }.isSuccess
        releaseRecorder()
        if (!written) {
            deleteFile()
            emit()
            return
        }
        finished = true
        emit()
    }

    /**
     * Ce qui vient d'être enregistré, prêt à joindre — ou `null` s'il n'y a
     * rien : trop court, fichier vide, micro jamais ouvert.
     *
     * La durée annoncée est **relue du fichier**, pas le compteur de l'écran :
     * c'est ce qui a réellement été écrit qui partira.
     */
    fun take(minimumMs: Int): Map<String, Any?>? {
        if (recorder != null) stop()
        val target = file
        if (!finished || target == null || !target.exists() || target.length() == 0L) {
            return null
        }

        val measured = durationOf(target) ?: elapsedMs
        if (measured < minimumMs) {
            deleteFile()
            reset()
            return null
        }

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            target,
        )
        val result = mapOf(
            "id" to UUID.randomUUID().toString(),
            "uri" to uri.toString(),
            "mimeType" to "audio/amr",
            "fileName" to target.name,
            "byteSize" to target.length().toInt(),
            "durationMs" to measured,
        )
        // Le brouillon appartient désormais au plateau : c'est lui qui décidera
        // de son sort, et l'enregistreur repart de rien.
        file = null
        reset()
        emit()
        return result
    }

    /** « Annuler » et « Recommencer » : le fichier n'a pas à survivre au geste. */
    fun discard() {
        release(deleteFile = true)
        emit()
    }

    fun detach() {
        handler.removeCallbacks(ticker)
        release(deleteFile = true)
        listener = null
    }

    /**
     * L'appareil sait-il retirer le bruit de fond ?
     *
     * `NoiseSuppressor.isAvailable()` dit si le traitement existe sur cet
     * appareil ; il ne se branche pas sur un `MediaRecorder`, qui n'expose pas
     * la session audio qu'il faudrait pour cela. Ce que l'app annonce est donc
     * bien ce que le système applique à la source `VOICE_COMMUNICATION` — et
     * elle se tait dès que l'un des deux manque.
     */
    fun hasNoiseSuppression(): Boolean = runCatching {
        NoiseSuppressor.isAvailable()
    }.getOrDefault(false)

    // ------------------------------------------------------------- interne

    private fun newRecorder(): MediaRecorder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

    private fun sample() {
        val current = recorder ?: return
        elapsedMs = (SystemClock.elapsedRealtime() - startedAt).toInt()
        val amplitude = runCatching { current.maxAmplitude }.getOrDefault(0)
        // Racine carrée : l'oreille n'entend pas l'amplitude linéairement, et
        // sans elle une parole normale resterait écrasée en bas de la piste —
        // même correction que pour la silhouette d'un vocal reçu.
        val level = sqrt(min(amplitude / MAX_AMPLITUDE, 1.0))
        levels.add(level)
        if (levels.size > KEPT_LEVELS) levels.removeAt(0)
        emit()
    }

    /** Le micro s'est dérobé en cours de route : tout est jeté. */
    private fun abort() {
        release(deleteFile = true)
        emit()
    }

    private fun release(deleteFile: Boolean) {
        handler.removeCallbacks(ticker)
        releaseRecorder()
        if (deleteFile) this.deleteFile()
        reset()
    }

    private fun releaseRecorder() {
        recorder?.let { current ->
            runCatching { current.reset() }
            runCatching { current.release() }
        }
        recorder = null
    }

    private fun deleteFile() {
        file?.let { runCatching { it.delete() } }
        file = null
    }

    private fun reset() {
        levels.clear()
        elapsedMs = 0
        finished = false
        noiseSuppressed = false
    }

    private fun durationOf(target: File): Int? {
        val retriever = MediaMetadataRetriever()
        val measured = runCatching {
            retriever.setDataSource(context, Uri.fromFile(target))
            retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toIntOrNull()
        }.getOrNull()
        runCatching { retriever.release() }
        return measured
    }

    private fun emit() {
        listener?.onState(
            mapOf(
                "phase" to when {
                    recorder != null -> "recording"
                    finished -> "recorded"
                    else -> "idle"
                },
                "elapsedMs" to elapsedMs,
                "levels" to ArrayList(levels),
                "noiseSuppression" to noiseSuppressed,
            )
        )
    }
}
