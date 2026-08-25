/// Port des brouillons : le texte tapé mais pas envoyé, restitué à la
/// réouverture du fil et signalé dans la liste des conversations.
abstract interface class DraftRepository {
  /// Brouillons indexés par `thread_id`.
  Future<Map<String, String>> listAll();

  Future<String?> get(String threadId);

  /// Enregistre le brouillon, ou l'efface si [body] est vide.
  Future<void> save(String threadId, String body);

  Future<void> remove(String threadId);
}
