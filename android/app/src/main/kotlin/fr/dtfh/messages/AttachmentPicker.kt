package fr.dtfh.messages

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/**
 * Sélection d'une pièce jointe par les écrans du système.
 *
 * Aucun plugin tiers : les sélecteurs sont des `Activity` à lancer et un
 * résultat à attendre, exactement comme la demande du rôle SMS que [SmsBridge]
 * gère déjà. Un plugin de plus n'apporterait ici qu'une dépendance.
 *
 * Ce que rend chaque source est un **brouillon** : une URI que l'app sait
 * relire, plus ce qu'il faut pour dessiner sa vignette avant l'envoi. Les
 * octets, eux, ne traversent le canal qu'au moment de l'aperçu.
 */
class AttachmentPicker(private val activity: Activity) {

    companion object {
        const val REQUEST_GALLERY = 4712
        const val REQUEST_CAMERA = 4713
        const val REQUEST_FILES = 4714
        const val REQUEST_CONTACT = 4715

        private val REQUEST_CODES = setOf(
            REQUEST_GALLERY,
            REQUEST_CAMERA,
            REQUEST_FILES,
            REQUEST_CONTACT,
        )
    }

    /** Sélection en cours. Une seule à la fois : c'est un écran modal. */
    private var pending: MethodChannel.Result? = null

    /**
     * Destination de la photo à prendre. L'appareil photo écrit dans un fichier
     * que *nous* fournissons : sans cela, il ne rendrait qu'une vignette
     * compressée dans les extras de l'intent.
     */
    private var cameraOutput: Uri? = null

    fun pick(source: String, result: MethodChannel.Result) {
        // Une demande qui en écrase une autre laisserait Dart à attendre pour
        // toujours : la précédente est close, à vide.
        pending?.success(emptyList<Map<String, Any?>>())
        pending = result

        val (intent, requestCode) = when (source) {
            "gallery" -> galleryIntent() to REQUEST_GALLERY
            "camera" -> cameraIntent() to REQUEST_CAMERA
            "files" -> filesIntent() to REQUEST_FILES
            "contactCard" -> contactIntent() to REQUEST_CONTACT
            else -> {
                finish(emptyList())
                return
            }
        }

        runCatching { activity.startActivityForResult(intent, requestCode) }
            .onFailure {
                // Aucune application pour honorer l'intent (émulateur sans
                // galerie, appareil sans caméra) : « rien choisi », pas une
                // erreur qui remonterait jusqu'à l'utilisateur.
                finish(emptyList())
            }
    }

    /** @return vrai si le résultat concernait une sélection de pièce jointe. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in REQUEST_CODES) return false
        if (resultCode != Activity.RESULT_OK) {
            discardCameraOutput()
            finish(emptyList())
            return true
        }

        val drafts = when (requestCode) {
            REQUEST_CAMERA -> listOfNotNull(
                cameraOutput?.let { describe(it, fallbackMime = "image/jpeg") }
            )
            REQUEST_CONTACT -> listOfNotNull(data?.data?.let { vCardOf(it) })
            else -> urisOf(data).mapNotNull { describe(it) }
        }
        cameraOutput = null
        finish(drafts)
        return true
    }

    private fun finish(drafts: List<Map<String, Any?>>) {
        pending?.success(drafts)
        pending = null
    }

    // ------------------------------------------------------------- intents

    private fun galleryIntent(): Intent =
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }

    private fun cameraIntent(): Intent {
        val directory = File(activity.cacheDir, "captures").apply { mkdirs() }
        val file = File(directory, "IMG_${UUID.randomUUID()}.jpg")
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            file,
        )
        cameraOutput = uri
        return Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
    }

    private fun filesIntent(): Intent =
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }

    private fun contactIntent(): Intent =
        Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)

    // ------------------------------------------------------------ résultats

    /** Une sélection multiple arrive en `ClipData`, une simple en `data`. */
    private fun urisOf(data: Intent?): List<Uri> {
        if (data == null) return emptyList()
        val clip: ClipData? = data.clipData
        if (clip != null) {
            return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
        }
        return listOfNotNull(data.data)
    }

    /**
     * Décrit une URI choisie : nom, type, poids.
     *
     * La permission de lecture est **persistée** quand le fournisseur
     * l'autorise : sans cela, l'URI serait révoquée à la rotation de l'écran ou
     * au retour de l'app, et l'envoi échouerait sur une pièce jointe qu'on voit
     * pourtant à l'écran.
     */
    private fun describe(uri: Uri, fallbackMime: String? = null): Map<String, Any?>? {
        runCatching {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }

        val mimeType = activity.contentResolver.getType(uri)
            ?: fallbackMime
            ?: "application/octet-stream"
        var fileName = uri.lastPathSegment ?: "piece-jointe"
        var size = 0L

        activity.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.stringOf(OpenableColumns.DISPLAY_NAME)?.let { fileName = it }
                size = cursor.longOf(OpenableColumns.SIZE)
            }
        }
        if (size == 0L) size = sizeOf(uri)
        if (size == 0L) return null

        val dimensions = dimensionsOf(uri, mimeType)
        return mapOf(
            "id" to UUID.randomUUID().toString(),
            "uri" to uri.toString(),
            "mimeType" to mimeType,
            "fileName" to fileName,
            "byteSize" to size.toInt(),
            "width" to dimensions?.first,
            "height" to dimensions?.second,
        )
    }

    /** Exporte le contact choisi en vCard, le format qu'un MMS sait porter. */
    private fun vCardOf(contactUri: Uri): Map<String, Any?>? {
        val (lookupKey, displayName) = activity.contentResolver.query(
            contactUri,
            arrayOf(
                ContactsContract.Contacts.LOOKUP_KEY,
                ContactsContract.Contacts.DISPLAY_NAME,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            cursor.getString(0) to cursor.getString(1)
        } ?: return null

        val vCardUri = Uri.withAppendedPath(
            ContactsContract.Contacts.CONTENT_VCARD_URI,
            lookupKey,
        )
        val bytes = runCatching {
            activity.contentResolver.openInputStream(vCardUri)?.use { it.readBytes() }
        }.getOrNull() ?: return null

        // La vCard est recopiée dans le cache : l'URI `CONTENT_VCARD_URI` n'est
        // lisible que par nous, or l'envoi la relira plus tard.
        val directory = File(activity.cacheDir, "captures").apply { mkdirs() }
        val file = File(directory, "${displayName ?: "contact"}.vcf")
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            file,
        )

        return mapOf(
            "id" to UUID.randomUUID().toString(),
            "uri" to uri.toString(),
            "mimeType" to "text/x-vcard",
            "fileName" to file.name,
            "byteSize" to bytes.size,
            "width" to null,
            "height" to null,
        )
    }

    /** Mesure une image sans la décoder — seuls ses en-têtes sont lus. */
    private fun dimensionsOf(uri: Uri, mimeType: String): Pair<Int, Int>? {
        if (!mimeType.startsWith("image/")) return null
        return runCatching {
            val options = android.graphics.BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            activity.contentResolver.openInputStream(uri)?.use {
                android.graphics.BitmapFactory.decodeStream(it, null, options)
            }
            if (options.outWidth > 0 && options.outHeight > 0) {
                options.outWidth to options.outHeight
            } else {
                null
            }
        }.getOrNull()
    }

    private fun sizeOf(uri: Uri): Long = runCatching {
        activity.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize }
            ?: 0L
    }.getOrDefault(0L)

    private fun discardCameraOutput() {
        val uri = cameraOutput ?: return
        cameraOutput = null
        discard(activity, uri)
    }

    private fun Cursor.stringOf(column: String): String? =
        getColumnIndex(column).takeIf { it >= 0 }?.let {
            if (isNull(it)) null else getString(it)
        }

    private fun Cursor.longOf(column: String): Long =
        getColumnIndex(column).takeIf { it >= 0 }?.let {
            if (isNull(it)) 0L else getLong(it)
        } ?: 0L
}

/**
 * Supprime ce qu'une sélection a laissé dans notre cache (photo prise puis
 * retirée du plateau, vCard exportée). Une URI que l'app ne possède pas est
 * laissée intacte : ce n'est pas à nous d'effacer la galerie de l'utilisateur.
 */
fun discard(activity: Activity, uri: Uri) {
    if (uri.authority != "${activity.packageName}.fileprovider") return
    val name = uri.lastPathSegment?.substringAfterLast('/') ?: return
    for (directory in listOf("captures", "mms")) {
        val file = File(File(activity.cacheDir, directory), name)
        if (file.exists()) {
            file.delete()
            return
        }
    }
}
