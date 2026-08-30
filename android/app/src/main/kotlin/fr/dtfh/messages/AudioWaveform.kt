package fr.dtfh.messages

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Mesure la silhouette d'une partie sonore : son intensité, tranche par
 * tranche.
 *
 * Rien dans `content://mms/part` ne la porte — il faut décoder le son pour la
 * connaître. `MediaExtractor` sort les trames compressées de la partie,
 * `MediaCodec` les rend en PCM, et on n'en garde que l'énergie : quelques
 * centaines de nombres pour un fichier qui en compte des millions.
 *
 * **Jamais sur le fil principal** : même écourté, un décodage se compte en
 * dizaines ou centaines de millisecondes. [AudioBridge] l'appelle depuis son
 * exécuteur.
 */
object AudioWaveform {

    /**
     * Nombre de points visé.
     *
     * Une piste affiche entre quarante et soixante barres. Décoder les trois
     * mille trames d'un vocal d'une minute pour n'en garder que soixante,
     * c'est payer quarante-neuf cinquantièmes du travail pour rien : on n'en
     * décode donc qu'une sur N, et N s'ajuste au fil de la lecture puisque la
     * longueur du fichier n'est pas connue d'avance.
     */
    private const val TARGET_FRAMES = 240

    /** Garde-fou sur un fichier aberrant : on ne parcourt pas une heure de son. */
    private const val MAX_SOURCE_FRAMES = 200_000L

    private const val TIMEOUT_US = 10_000L

    /**
     * Silhouettes déjà mesurées, par identifiant de partie. Le contenu d'une
     * partie ne change jamais, et la mesure est ce qu'il y a de plus cher dans
     * l'affichage d'une bulle : elle ne se refait pas au défilement.
     */
    private val cache = ConcurrentHashMap<String, List<Double>>()

    /** Mémorise aussi les échecs, pour ne pas réessayer un format indécodable. */
    private val failed = ConcurrentHashMap.newKeySet<String>()

    fun of(context: Context, partId: String, buckets: Int): List<Double>? {
        cache[partId]?.let { return resample(it, buckets) }
        if (partId in failed) return null

        // Seules les parties du stock se retiennent sur le disque : leur
        // contenu ne change jamais, et leur `_id` en est la clé. Un brouillon,
        // lui, vit le temps d'une rédaction — le retenir laisserait des
        // silhouettes orphelines derrière chaque vocal jeté.
        val durable = AudioSource.isStoredPart(partId)

        // Le cache mémoire meurt avec le processus : sans celui du disque,
        // chaque lancement de l'app redécoderait les mêmes vocaux.
        if (durable) {
            readCache(context, partId)?.let { stored ->
                cache[partId] = stored
                return resample(stored, buckets)
            }
        }

        val frames = runCatching { decode(context, partId) }.getOrNull()
        if (frames.isNullOrEmpty()) {
            failed.add(partId)
            return null
        }
        cache[partId] = frames
        if (durable) writeCache(context, partId, frames)
        return resample(frames, buckets)
    }

    /**
     * Énergie (RMS) des trames décodées, normalisée sur le maximum du fichier.
     *
     * Normaliser est indispensable : un vocal enregistré à bout de bras et un
     * autre collé au micro n'ont pas le même niveau absolu, alors qu'ils
     * doivent se dessiner pareil. Ce qu'on lit d'une forme d'onde est un
     * relief, pas un volume.
     */
    private fun decode(context: Context, partId: String): List<Double> {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        val frames = ArrayList<Double>()

        try {
            extractor.setDataSource(context, AudioSource.uriOf(partId), null)

            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index)
                    .getString(MediaFormat.KEY_MIME)
                    ?.startsWith("audio/") == true
            } ?: return emptyList()

            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return emptyList()
            extractor.selectTrack(track)

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false

            // Une trame sur [stride] est décodée. Le pas double dès qu'on a
            // deux fois trop de points, et ceux déjà mesurés sont fondus deux à
            // deux : la silhouette couvre toujours tout le fichier, quel que
            // soit sa longueur, pour un travail borné.
            var stride = 1L
            var seen = 0L

            while (!outputDone && seen < MAX_SOURCE_FRAMES) {
                if (!inputDone) {
                    val index = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (index >= 0) {
                        val buffer = codec.getInputBuffer(index)
                        var queued = false
                        while (!queued && !inputDone) {
                            if (seen % stride != 0L) {
                                // Sautée : la trame est passée sans être lue ni
                                // décodée. C'est là qu'est l'économie.
                                seen++
                                if (!extractor.advance()) {
                                    codec.queueInputBuffer(
                                        index, 0, 0, 0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                    )
                                    inputDone = true
                                }
                                continue
                            }
                            val size =
                                if (buffer == null) -1 else extractor.readSampleData(buffer, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(
                                    index, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                                queued = true
                                seen++
                                extractor.advance()
                            }
                        }
                    }
                }

                val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (index >= 0) {
                    if (info.size > 0) {
                        codec.getOutputBuffer(index)?.let { buffer ->
                            frames.add(rmsOf(buffer, info.offset, info.size))
                        }
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true

                    if (frames.size >= TARGET_FRAMES * 2) {
                        foldByPairs(frames)
                        stride *= 2
                    }
                }
            }
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            runCatching { extractor.release() }
        }

        val peak = frames.maxOrNull() ?: 0.0
        // Un enregistrement muet n'a pas de relief : mieux vaut ne rien
        // dessiner que d'amplifier du bruit de fond jusqu'au plafond.
        if (peak <= 0.0) return emptyList()

        return frames.map { level ->
            // Racine carrée : l'oreille n'entend pas l'énergie linéairement, et
            // sans elle une parole normale reste écrasée en bas de la piste.
            sqrt(level / peak).coerceIn(0.0, 1.0)
        }
    }

    /**
     * Réduit de moitié en gardant le plus fort de chaque paire — jamais leur
     * moyenne, qui gommerait les attaques.
     */
    private fun foldByPairs(frames: ArrayList<Double>) {
        val kept = frames.size / 2
        for (index in 0 until kept) {
            frames[index] = max(frames[index * 2], frames[index * 2 + 1])
        }
        frames.subList(kept, frames.size).clear()
    }

    /** Énergie moyenne d'un tampon PCM 16 bits. */
    private fun rmsOf(buffer: ByteBuffer, offset: Int, size: Int): Double {
        val samples = buffer.duplicate().apply {
            position(offset)
            limit(offset + size)
            order(ByteOrder.nativeOrder())
        }.asShortBuffer()

        var sum = 0.0
        var count = 0
        while (samples.hasRemaining()) {
            val value = samples.get() / 32768.0
            sum += value * value
            count++
        }
        return if (count == 0) 0.0 else sqrt(sum / count)
    }

    /**
     * Ramène la mesure au nombre de barres demandé, en gardant le **maximum**
     * de chaque intervalle : moyenner aplatirait les attaques, et une forme
     * d'onde sans attaques ne ressemble plus à de la parole.
     */
    private fun resample(frames: List<Double>, buckets: Int): List<Double> {
        if (buckets <= 0 || frames.isEmpty()) return emptyList()
        if (buckets >= frames.size) return frames
        return List(buckets) { index ->
            val start = index * frames.size / buckets
            val end = max(start + 1, (index + 1) * frames.size / buckets)
            var peak = 0.0
            for (i in start until minOf(end, frames.size)) {
                if (frames[i] > peak) peak = frames[i]
            }
            peak
        }
    }

    // ---------------------------------------------------------- cache disque

    /**
     * `cacheDir` et non un stockage durable : une silhouette se remesure, et
     * le système est libre de faire le ménage quand la place manque.
     */
    private fun cacheFile(context: Context, partId: String): File {
        val digits = partId.filter { it.isDigit() }
        val key = digits.ifEmpty { partId.hashCode().toString().replace('-', 'n') }
        return File(context.cacheDir, "waveform-$key")
    }

    private fun readCache(context: Context, partId: String): List<Double>? = runCatching {
        val file = cacheFile(context, partId)
        if (!file.exists()) return null
        file.readText()
            .split(',')
            .mapNotNull { it.toDoubleOrNull() }
            .takeIf { it.isNotEmpty() }
    }.getOrNull()

    private fun writeCache(context: Context, partId: String, frames: List<Double>) {
        runCatching {
            // `Locale.US` : en français, `%.3f` écrirait « 0,123 » dans une
            // liste séparée par des virgules.
            cacheFile(context, partId).writeText(
                frames.joinToString(",") { String.format(Locale.US, "%.3f", it) }
            )
        }
    }
}
