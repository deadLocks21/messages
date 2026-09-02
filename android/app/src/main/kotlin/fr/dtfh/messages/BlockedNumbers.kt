package fr.dtfh.messages

import android.content.ContentValues
import android.content.Context
import android.provider.BlockedNumberContract

/**
 * Les numéros bloqués, tels qu'Android les tient.
 *
 * Pas de liste à nous : `BlockedNumberContract` est la liste **du système**,
 * partagée avec le composeur d'appel — c'est ce qui permet de tenir la
 * promesse du dialogue (« vous ne recevrez plus ni appels ni messages de ce
 * numéro ») plutôt que la moitié qui nous regarde. Y écrire est réservé à
 * l'app SMS par défaut et au composeur par défaut ; nous sommes la première.
 *
 * Lu depuis `SmsDeliverReceiver`, qui s'exécute sans moteur Dart : rien ici ne
 * doit dépendre de Flutter.
 */
object BlockedNumbers {
    fun list(context: Context): List<String> {
        val numbers = mutableListOf<String>()
        runCatching {
            context.contentResolver.query(
                BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                arrayOf(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER),
                null,
                null,
                null,
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    cursor.getString(0)?.takeIf { it.isNotBlank() }?.let(numbers::add)
                }
            }
        }
        return numbers
    }

    fun block(context: Context, number: String) {
        val values = ContentValues().apply {
            put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, number)
        }
        runCatching {
            context.contentResolver.insert(
                BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                values,
            )
        }
    }

    fun unblock(context: Context, number: String) {
        runCatching { BlockedNumberContract.unblock(context, number) }
    }

    /**
     * Le numéro est-il bloqué ? La comparaison est celle du système, qui
     * connaît les formes d'un même numéro mieux que nous.
     *
     * Rend `false` si l'appel échoue — nous ne sommes plus l'app SMS par
     * défaut, par exemple. Un message de trop vaut mieux qu'un message perdu.
     */
    fun isBlocked(context: Context, number: String): Boolean =
        runCatching { BlockedNumberContract.isBlocked(context, number) }
            .getOrDefault(false)
}
