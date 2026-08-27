package fr.dtfh.messages

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteOrder
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
 * dizaines de nombres pour un fichier qui en compte des millions.
 *
 * **Jamais sur le fil principal** : décoder une minute de parole prend des
 * centaines de millisecondes. [AudioBridge] l'appelle depuis son exécuteur.
 */
object AudioWaveform {

    /** Au-delà, on ne mesure plus : un MMS ne porte pas un album. */
    private const val MAX_FRAMES = 20_000

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

        val frames = runCatching { decode(context, partId) }.getOrNull()
        if (frames.isNullOrEmpty()) {
            failed.add(partId)
            return null
        }
        cache[partId] = frames
        return resample(frames, buckets)
    }

    /**
     * Énergie (RMS) de chaque trame décodée, normalisée sur le maximum du
     * fichier.
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
            extractor.setDataSource(context, MmsStore.partUri(partId), null)

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

            while (!outputDone && frames.size < MAX_FRAMES) {
                if (!inputDone) {
                    val index = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (index >= 0) {
                        val buffer = codec.getInputBuffer(index)
                        val size = if (buffer == null) -1 else extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
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

    private const val TIMEOUT_US = 10_000L

    /** Énergie moyenne d'un tampon PCM 16 bits. */
    private fun rmsOf(buffer: java.nio.ByteBuffer, offset: Int, size: Int): Double {
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
}
