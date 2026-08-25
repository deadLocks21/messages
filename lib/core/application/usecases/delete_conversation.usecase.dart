import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/domain/services/draft.repository.dart';

/// Supprime un fil et tout ce que l'app tenait à son sujet.
///
/// L'ordre compte peu, mais les réglages et le brouillon sont nettoyés dans
/// tous les cas : un `thread_id` réattribué plus tard par Android ne doit pas
/// hériter de l'épinglage d'un fil disparu.
class DeleteConversationUseCase {
  final ConversationRepository _conversations;
  final ConversationPreferencesRepository _preferences;
  final DraftRepository _drafts;

  const DeleteConversationUseCase({
    required ConversationRepository conversations,
    required ConversationPreferencesRepository preferences,
    required DraftRepository drafts,
  }) : _conversations = conversations,
       _preferences = preferences,
       _drafts = drafts;

  Future<void> execute(String threadId) async {
    await _conversations.delete(threadId);
    await _preferences.remove(threadId);
    await _drafts.remove(threadId);
  }
}
