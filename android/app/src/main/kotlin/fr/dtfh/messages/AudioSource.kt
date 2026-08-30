package fr.dtfh.messages

import android.net.Uri

/**
 * Ce qu'un identifiant de son désigne réellement.
 *
 * Deux formes traversent le canal audio, et l'appelant Dart n'a pas à les
 * distinguer : le `_id` d'une partie du stock (`content://mms/part/<id>`), et
 * l'URI d'un brouillon pas encore envoyé — le vocal qu'on vient d'enregistrer
 * et qu'on réécoute avant de le joindre.
 *
 * Un seul endroit tranche, ici, pour que le lecteur, la mesure de silhouette et
 * l'enregistreur ouvrent exactement le même flux.
 */
object AudioSource {

    fun uriOf(id: String): Uri =
        if (isStoredPart(id)) MmsStore.partUri(id) else Uri.parse(id)

    /**
     * Une partie du stock est désignée par son `_id`, un entier. Tout le reste
     * est une URI — et [MmsStore.partUri] lèverait dessus.
     */
    fun isStoredPart(id: String): Boolean = id.toLongOrNull() != null
}
