import 'package:messages/core/domain/services/conversation.repository.dart';

/// Marque lus tous les entrants d'un fil. Appelé à l'ouverture du fil et depuis
/// le menu contextuel de la liste.
class MarkConversationReadUseCase {
  final ConversationRepository _conversations;

  const MarkConversationReadUseCase(this._conversations);

  Future<void> execute(String threadId) => _conversations.markRead(threadId);
}
