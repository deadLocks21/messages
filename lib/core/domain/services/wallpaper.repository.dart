/// Port du fond d'écran d'un fil.
///
/// Ranger une copie de l'image dans le stockage de l'app plutôt que de retenir
/// l'URI choisie : un `content://` de la galerie ne survit ni au redémarrage —
/// la permission de lecture est éphémère — ni à la photo qu'on supprime. Un
/// fond d'écran doit tenir plus longtemps que ça.
abstract interface class WallpaperRepository {
  /// Rend le chemin de la copie, ou `null` si l'image n'a pas pu être lue.
  Future<String?> save({required String threadId, required String uri});
}
