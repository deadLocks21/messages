package fr.dtfh.messages

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executor

/**
 * Passe une partie de MMS au reste du système : à l'application qui sait
 * l'ouvrir, ou au fichier que l'utilisateur choisit pour la garder.
 *
 * **La partie ne peut pas être passée telle quelle.** `content://mms/part/<id>`
 * n'est lisible que par l'application SMS par défaut : le provider Telephony
 * n'accorde pas de permission d'URI à un tiers, et l'application appelée se
 * verrait refuser la lecture. La partie est donc **recopiée** — dans le cache
 * pour un prêt le temps d'un intent, ou directement dans la destination
 * choisie pour un enregistrement.
 *
 * L'enregistrement passe par `ACTION_CREATE_DOCUMENT` plutôt que par un dossier
 * « Téléchargements » écrit en direct : aucune permission n'est requise, à
 * n'importe quelle version d'Android, et c'est l'utilisateur qui décide où le
 * fichier atterrit.
 */
class AttachmentOpener(
    private val activity: Activity,
    private val io: Executor,
    private val main: Handler,
) {

    companion object {
        const val REQUEST_SAVE = 4716

        private const val DIRECTORY = "shared"

        /** Une copie prêtée n'a pas à survivre à la journée. */
        private const val STALE_MS = 24L * 60 * 60 * 1000

        private const val FALLBACK_MIME = "application/octet-stream"
    }

    /** Enregistrement en cours. Un seul à la fois : c'est un écran modal. */
    private var pendingSave: MethodChannel.Result? = null
    private var pendingPartId: String? = null

    /**
     * Ouvre la partie dans l'application la plus adaptée. Rend `false` quand il
     * n'y en a aucune — un type exotique, un appareil sans lecteur de PDF.
     */
    fun open(
        partId: String,
        mimeType: String,
        fileName: String?,
        result: MethodChannel.Result,
    ) {
        // La copie est de l'entrée-sortie ; le lancement d'une activité ne se
        // fait, lui, que depuis le fil principal.
        io.execute {
            val staged = stage(partId, fileName)
            main.post {
                result.success(staged != null && view(staged, mimeType))
            }
        }
    }

    /** Demande où enregistrer, puis y recopie la partie. */
    fun save(
        partId: String,
        mimeType: String,
        fileName: String?,
        result: MethodChannel.Result,
    ) {
        // Une demande qui en écrase une autre laisserait Dart à attendre pour
        // toujours : la précédente est close, sur un échec.
        pendingSave?.success(false)
        pendingSave = result
        pendingPartId = partId

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType.ifEmpty { FALLBACK_MIME }
            putExtra(Intent.EXTRA_TITLE, safeName(partId, fileName))
        }
        runCatching { activity.startActivityForResult(intent, REQUEST_SAVE) }
            .onFailure { finish(false) }
    }

    /** @return vrai si le résultat concernait un enregistrement. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SAVE) return false

        val destination = data?.data
        val partId = pendingPartId
        pendingPartId = null
        if (resultCode != Activity.RESULT_OK || destination == null || partId == null) {
            // Annulé : ce n'est pas un échec, mais rien n'a été écrit.
            finish(false)
            return true
        }

        val result = pendingSave
        pendingSave = null
        io.execute {
            val written = copyInto(partId, destination)
            main.post { result?.success(written) }
        }
        return true
    }

    private fun finish(written: Boolean) {
        pendingSave?.success(written)
        pendingSave = null
        pendingPartId = null
    }

    // ------------------------------------------------------------- copies

    /**
     * Recopie la partie dans le cache et rend l'URI que le `FileProvider` sait
     * prêter. `null` si la partie ne se lit pas.
     */
    private fun stage(partId: String, fileName: String?): Uri? = runCatching {
        val bytes = MmsStore(activity).readPart(partId) ?: return null
        val directory = File(activity.cacheDir, DIRECTORY).apply { mkdirs() }
        sweepStale(directory)
        val file = File(directory, safeName(partId, fileName))
        file.writeBytes(bytes)
        FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
    }.getOrNull()

    private fun view(uri: Uri, mimeType: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType.ifEmpty { FALLBACK_MIME })
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return runCatching { activity.startActivity(intent) }.isSuccess
    }

    private fun copyInto(partId: String, destination: Uri): Boolean = runCatching {
        val bytes = MmsStore(activity).readPart(partId) ?: return false
        activity.contentResolver.openOutputStream(destination)?.use { it.write(bytes) }
            ?: return false
        true
    }.getOrDefault(false)

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
