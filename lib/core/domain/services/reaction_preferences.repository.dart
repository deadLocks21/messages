/// Port du réglage d'affichage des réactions.
///
/// Google Messages a le même (« Afficher les réactions iPhone en tant
/// qu'emoji »), et pour la même raison : le repli repose sur la reconnaissance
/// d'une phrase, donc sur une heuristique. Le jour où elle se trompe — un
/// message avalé, une réaction posée sur la mauvaise bulle — il faut pouvoir la
/// couper et revoir ce que le stock contient réellement, sans réinstaller quoi
/// que ce soit.
abstract interface class ReactionPreferencesRepository {
  /// Les réactions sont-elles repliées dans les bulles ? Vrai par défaut.
  Future<bool> foldsReactions();

  Future<void> setFoldsReactions(bool value);
}
