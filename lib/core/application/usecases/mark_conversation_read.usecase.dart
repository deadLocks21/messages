import 'package:messages/core/domain/services/conversation.repository.dart';

/// Marque lus tous les entrants d'un fil. Appelé à l'ouverture du fil et depuis
/// le menu contextuel de la liste.
///
/// Rend `true` si le stock a bougé — l'appelant n'a rien à rafraîchir sinon.
class MarkConversationReadUseCase {
  final ConversationRepository _conversations;

  const MarkConversationReadUseCase(this._conversations);

  Future<bool> execute(String threadId) => _conversations.markRead(threadId);
}
