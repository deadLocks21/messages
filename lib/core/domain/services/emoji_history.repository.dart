/// Port des **emoji récemment utilisés**.
///
/// C'est le seul état de l'app qui distingue un clavier d'emoji utile d'une
/// grille de trois mille caractères : neuf fois sur dix, celui qu'on cherche
/// est celui qu'on a déjà mis. Il ne vit donc pas en mémoire — l'app d'origine
/// s'en souvient d'une session à l'autre, et l'oublier reviendrait à retomber
/// chaque matin sur « Vous n'avez encore utilisé aucun emoji ».
///
/// Les caractères sont rendus **du plus récent au plus ancien**, dédoublonnés.
abstract interface class EmojiHistoryRepository {
  Future<List<String>> recents();

  /// Retient [character] en tête. Le réutiliser le remonte plutôt que de
  /// l'ajouter deux fois.
  Future<void> remember(String character);

  /// Combien on en garde : deux rangées de neuf, comme au relevé. Au-delà, la
  /// section pousserait la grille hors de l'écran pour ranger des emoji qu'on
  /// n'a mis qu'une fois.
  static const maxCount = 18;
}
