import 'package:messages/core/application/services/logger_application.service.dart';
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
  final LoggerApplicationService _logger;

  const DeleteConversationUseCase({
    required ConversationRepository conversations,
    required ConversationPreferencesRepository preferences,
    required DraftRepository drafts,
    required LoggerApplicationService logger,
  }) : _conversations = conversations,
       _preferences = preferences,
       _drafts = drafts,
       _logger = logger;

  Future<void> execute(String threadId) async {
    try {
      await _conversations.delete(threadId);
      await _preferences.remove(threadId);
      await _drafts.remove(threadId);
      await _logger.info(
        'conversation.deleted',
        attrs: {'thread.id': threadId},
      );
    } catch (e, stack) {
      // Irréversible et pourtant faillible : l'échec en cours de route laisse
      // un fil à moitié nettoyé, ce qu'aucun écran ne montre.
      await _logger.error(
        'conversation.delete_failed',
        attrs: {'thread.id': threadId},
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }
}
