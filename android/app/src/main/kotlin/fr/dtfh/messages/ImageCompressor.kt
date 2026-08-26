package fr.dtfh.messages

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/**
 * Réduit une image pour qu'elle tienne dans un MMS.
 *
 * Une photo d'appareil pèse plusieurs mégaoctets ; un MMS en accepte quelques
 * centaines de kilooctets. Sans cette étape, la source « Appareil photo » ne
 * servirait à rien — c'est le cas le plus courant, et c'était le seul qui ne
 * pouvait jamais aboutir.
 *
 * La recherche est volontairement simple : on descend en qualité JPEG d'abord,
 * ce qui coûte peu visuellement, puis on rétrécit l'image quand la qualité
 * seule ne suffit plus. On s'arrête à un plancher plutôt que de produire une
 * bouillie de pixels qui tiendrait dans le budget sans rien montrer.
 */
object ImageCompressor {

    /** Côté le plus long, en pixels, pour un premier essai. */
    private const val MAX_DIMENSION = 1600

    /** En dessous, l'image ne vaut plus la peine d'être envoyée. */
    private const val MIN_DIMENSION = 320

    /** Qualités JPEG essayées, de la meilleure à la plus basse. */
    private val QUALITIES = intArrayOf(85, 70, 55, 40)

    /** Facteur de réduction entre deux passes. */
    private const val SCALE_STEP = 0.7

    /**
     * @return le descriptif de l'image allégée, ou `null` si la cible est hors
     * d'atteinte.
     */
    fun compress(
        context: Context,
        sourceUri: Uri,
        targetBytes: Int,
    ): Map<String, Any?>? {
        val bounds = readBounds(context, sourceUri) ?: return null
        var bitmap = decodeScaled(context, sourceUri, bounds, MAX_DIMENSION)
            ?: return null
        bitmap = applyExifRotation(context, sourceUri, bitmap)

        try {
            while (true) {
                for (quality in QUALITIES) {
                    val encoded = encode(bitmap, quality)
                    if (encoded.size <= targetBytes) {
                        return write(context, encoded, bitmap.width, bitmap.height)
                    }
                }

                val nextWidth = (bitmap.width * SCALE_STEP).toInt()
                val nextHeight = (bitmap.height * SCALE_STEP).toInt()
                if (nextWidth < MIN_DIMENSION || nextHeight < MIN_DIMENSION) {
                    // Même au plancher et à la qualité la plus basse, ça ne
                    // rentre pas : mieux vaut le dire que d'envoyer n'importe
                    // quoi.
                    return null
                }
                val smaller = Bitmap.createScaledBitmap(
                    bitmap,
                    nextWidth,
                    nextHeight,
                    true,
                )
                if (smaller != bitmap) bitmap.recycle()
                bitmap = smaller
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun readBounds(context: Context, uri: Uri): BitmapFactory.Options? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        runCatching {
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, options)
            }
        }
        return if (options.outWidth > 0 && options.outHeight > 0) options else null
    }

    /**
     * Décode déjà réduit.
     *
     * `inSampleSize` fait le rééchantillonnage **pendant** le décodage : une
     * photo de 12 Mpx occuperait 48 Mo en mémoire si on la décodait entière,
     * de quoi faire tomber le process avant même d'avoir compressé.
     */
    private fun decodeScaled(
        context: Context,
        uri: Uri,
        bounds: BitmapFactory.Options,
        maxDimension: Int,
    ): Bitmap? {
        var sample = 1
        var width = bounds.outWidth
        var height = bounds.outHeight
        while (width / sample > maxDimension || height / sample > maxDimension) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return runCatching {
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, options)
            }
        }.getOrNull()
    }

    /**
     * Remet la photo d'aplomb.
     *
     * L'appareil photo n'oriente pas les pixels : il écrit l'orientation dans
     * les métadonnées EXIF, que `BitmapFactory` ignore. Ré-encoder sans les
     * lire enverrait tous les portraits couchés.
     */
    private fun applyExifRotation(
        context: Context,
        uri: Uri,
        bitmap: Bitmap,
    ): Bitmap {
        val orientation = runCatching {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                ExifInterface(stream).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            }
        }.getOrNull() ?: ExifInterface.ORIENTATION_NORMAL

        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            else -> return bitmap
        }

        val rotated = runCatching {
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        }.getOrNull() ?: return bitmap
        if (rotated != bitmap) bitmap.recycle()
        return rotated
    }

    private fun encode(bitmap: Bitmap, quality: Int): ByteArray {
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
        return out.toByteArray()
    }

    /**
     * Dépose le résultat dans le cache, derrière le `FileProvider` : c'est de
     * là que le service MMS du système ira le lire, sous sa propre identité.
     */
    private fun write(
        context: Context,
        bytes: ByteArray,
        width: Int,
        height: Int,
    ): Map<String, Any?> {
        val directory = File(context.cacheDir, "captures").apply { mkdirs() }
        val file = File(directory, "MMS_${UUID.randomUUID()}.jpg")
        file.writeBytes(bytes)
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        return mapOf(
            "uri" to uri.toString(),
            "byteSize" to bytes.size,
            "width" to width,
            "height" to height,
            // Le ré-encodage produit toujours du JPEG, quel que soit l'original.
            "mimeType" to "image/jpeg",
        )
    }
}
