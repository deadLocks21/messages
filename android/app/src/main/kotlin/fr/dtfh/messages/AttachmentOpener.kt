package fr.dtfh.messages

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/**
 * Passe une partie de MMS à l'application du système qui sait l'ouvrir.
 *
 * **La partie ne peut pas être passée telle quelle.** `content://mms/part/<id>`
 * n'est lisible que par l'application SMS par défaut : le provider Telephony
 * n'accorde pas de permission d'URI à un tiers, et l'application appelée se
 * verrait refuser la lecture. La partie est donc **recopiée** dans le cache,
 * d'où le `FileProvider` de l'app peut la prêter, le temps d'un intent.
 *
 * Le nom du fichier compte : c'est celui que verra l'application appelée, et
 * beaucoup se fient à son extension plus qu'au type déclaré.
 */
object AttachmentOpener {

    private const val DIRECTORY = "shared"

    /** Une copie prêtée n'a pas à survivre à la journée. */
    private const val STALE_MS = 24L * 60 * 60 * 1000

    /**
     * Recopie la partie dans le cache et rend l'URI que le `FileProvider` sait
     * prêter. `null` si la partie ne se lit pas.
     */
    fun stage(activity: Activity, partId: String, fileName: String?): Uri? = runCatching {
        val bytes = MmsStore(activity).readPart(partId) ?: return null
        val directory = File(activity.cacheDir, DIRECTORY).apply { mkdirs() }
        sweepStale(directory)
        val file = File(directory, safeName(partId, fileName))
        file.writeBytes(bytes)
        FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
    }.getOrNull()

    /**
     * Ouvre [uri] dans l'application la plus adaptée. Rend `false` quand il n'y
     * en a aucune — un type exotique, un appareil sans lecteur de PDF.
     */
    fun view(activity: Activity, uri: Uri, mimeType: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return runCatching { activity.startActivity(intent) }.isSuccess
    }

    /**
     * Le nom annoncé par l'émetteur, débarrassé de tout ce qui pourrait sortir
     * du dossier — un nom de fichier venu d'un MMS n'est pas de confiance.
     */
    private fun safeName(partId: String, fileName: String?): String {
        val cleaned = fileName
            ?.substringAfterLast('/')
            ?.substringAfterLast('\\')
            ?.filter { it.isLetterOrDigit() || it in "-_. " }
            ?.trim()
            ?.take(120)
        return if (cleaned.isNullOrEmpty()) "piece-jointe-$partId" else cleaned
    }

    private fun sweepStale(directory: File) {
        val deadline = System.currentTimeMillis() - STALE_MS
        directory.listFiles()?.forEach { file ->
            if (file.lastModified() < deadline) runCatching { file.delete() }
        }
    }
}
