package fr.dtfh.messages

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import javax.net.ssl.HttpsURLConnection

/**
 * Rapatriement d'un média distant — le GIF choisi dans le catalogue.
 *
 * Le téléchargement est fait ici et non en Dart pour la raison qui vaut
 * partout ailleurs : **les octets ne traversent pas le canal**. Le fichier
 * doit de toute façon finir dans le cache, derrière le `FileProvider`, parce
 * que c'est de là que l'envoi du MMS ira le relire ; le faire descendre en
 * Dart pour le remonter aussitôt ne ferait que doubler le trajet.
 *
 * Ce que rend [download] est le même **brouillon** que celui d'une photo
 * choisie dans la galerie : une URI, un type, un nom, un poids, des
 * dimensions. Rien qui distingue, plus loin dans l'app, un GIF venu du réseau
 * d'une image venue de l'appareil.
 */
class RemoteMedia(private val context: Context) {

    companion object {
        const val DIRECTORY = "gifs"

        /**
         * Plafond de ce qu'on accepte de recevoir.
         *
         * Le budget réel de l'opérateur est bien plus bas et c'est Dart qui
         * l'applique, avant même de choisir la déclinaison ; celui-ci n'est
         * qu'un garde-fou contre une adresse qui se mettrait à servir un
         * fichier sans fin — un `Content-Length` menteur ne doit pas pouvoir
         * remplir le cache du téléphone.
         */
        private const val MAX_BYTES = 8 * 1024 * 1024

        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 30_000
    }

    /**
     * Télécharge [url] dans `cacheDir/gifs/` et décrit ce qui a été écrit.
     *
     * Lève quand rien d'exploitable n'est arrivé : l'appelant doit pouvoir le
     * dire, un plateau qui reste vide passerait pour un appui sans effet.
     */
    fun download(url: String, mimeType: String, fileName: String): Map<String, Any?> {
        // Seul HTTPS : une adresse en clair pourrait être remplacée en chemin,
        // et rien de ce que sert un catalogue de GIF ne le justifie.
        val parsed = runCatching { URL(url) }.getOrNull()
        if (parsed == null || !parsed.protocol.equals("https", ignoreCase = true)) {
            throw MediaDownloadException("unsupported url")
        }

        val bytes = try {
            val connection = (parsed.openConnection() as HttpsURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
            }
            try {
                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    throw MediaDownloadException("http ${'$'}{connection.responseCode}")
                }
                connection.inputStream.use { it.readAtMost(MAX_BYTES) }
            } finally {
                connection.disconnect()
            }
        } catch (e: MediaDownloadException) {
            throw e
        } catch (e: java.io.IOException) {
            // Hors ligne, DNS muet, connexion coupée en route : tout cela dit
            // la même chose à l'utilisateur, et rien de plus.
            throw MediaDownloadException(e.message ?: "network")
        }
        if (bytes.isEmpty()) throw MediaDownloadException("empty body")

        // Le nom vient du descriptif du GIF et peut donc se répéter d'un envoi
        // à l'autre : un préfixe unique évite qu'un second GIF écrase le
        // premier, encore posé sur le plateau.
        val directory = File(context.cacheDir, DIRECTORY).apply { mkdirs() }
        val file = File(directory, "${UUID.randomUUID()}-${fileName.sanitized()}")
        file.writeBytes(bytes)

        val uri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )

        val dimensions = dimensionsOf(bytes)
        return mapOf(
            "id" to UUID.randomUUID().toString(),
            "uri" to uri.toString(),
            "mimeType" to mimeType,
            "fileName" to fileName,
            "byteSize" to bytes.size,
            "width" to dimensions?.first,
            "height" to dimensions?.second,
        )
    }

    /**
     * Mesure l'image sans la décoder — seuls ses en-têtes sont lus. Un GIF
     * animé de 500 × 500 occuperait sinon toutes ses images en mémoire pour
     * n'en rendre que deux nombres.
     */
    private fun dimensionsOf(bytes: ByteArray): Pair<Int, Int>? = runCatching {
        val options = android.graphics.BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        if (options.outWidth > 0 && options.outHeight > 0) {
            options.outWidth to options.outHeight
        } else {
            null
        }
    }.getOrNull()
}

/**
 * Lit le flux, en s'arrêtant net au-delà de [limit].
 *
 * `readBytes()` ferait confiance à ce qui arrive : ici, ce qui arrive vient
 * d'ailleurs.
 */
private fun java.io.InputStream.readAtMost(limit: Int): ByteArray {
    val buffer = java.io.ByteArrayOutputStream()
    val chunk = ByteArray(16 * 1024)
    while (true) {
        val read = read(chunk)
        if (read < 0) break
        if (buffer.size() + read > limit) throw MediaDownloadException("too large")
        buffer.write(chunk, 0, read)
    }
    return buffer.toByteArray()
}

/** Ce qui empêche un média distant d'arriver. */
class MediaDownloadException(message: String) : Exception(message)

/**
 * Ce que le descriptif d'un GIF a le droit de devenir : un nom de fichier, et
 * rien qui puisse sortir du dossier où on l'écrit.
 */
private fun String.sanitized(): String {
    val cleaned = substringAfterLast('/').substringAfterLast('\\')
        .filter { it.isLetterOrDigit() || it == '.' || it == '-' || it == '_' }
    return cleaned.ifEmpty { "media.gif" }
}
