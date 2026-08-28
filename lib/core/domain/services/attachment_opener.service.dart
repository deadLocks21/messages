/// Ce qu'on peut faire d'une pièce jointe hors de l'app : l'ouvrir ailleurs,
/// ou la garder.
///
/// L'app sait montrer une image et faire écouter un vocal ; elle ne sait pas
/// afficher un PDF, ni jouer une vidéo, ni ajouter une vCard au carnet
/// d'adresses — et n'a aucune raison d'apprendre : le système a déjà, pour
/// chacun de ces types, une application que l'utilisateur a choisie. Le rôle
/// de la messagerie s'arrête à la lui passer.
abstract interface class AttachmentOpener {
  /// Confie [attachmentId] à l'application la plus adaptée à [mimeType].
  ///
  /// Rend `false` quand aucune ne sait l'ouvrir : c'est une réponse, pas une
  /// erreur — la bulle le dit à l'utilisateur plutôt que de rester muette.
  /// [fileName] est celui que verra l'application appelée ; à défaut, un nom
  /// est fabriqué à partir du type.
  Future<bool> open(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  });

  /// Enregistre [attachmentId] dans le fichier que l'utilisateur choisit.
  ///
  /// Le recours quand personne ne sait ouvrir la pièce jointe : elle n'est pas
  /// perdue pour autant, on peut toujours la garder et s'en occuper ailleurs.
  ///
  /// Rend `false` si rien n'a été écrit — l'utilisateur a renoncé, ou la
  /// destination n'était pas accessible.
  Future<bool> save(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  });
}
