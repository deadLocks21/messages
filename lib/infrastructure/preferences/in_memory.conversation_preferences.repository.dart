import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';

/// Réglages de fil en mémoire.
class InMemoryConversationPreferencesRepository
    implements ConversationPreferencesRepository {
  final Map<String, ConversationPreference> _byThreadId = {};

  @override
  Future<List<ConversationPreference>> listAll() async =>
      List.unmodifiable(_byThreadId.values);

  @override
  Future<void> save(ConversationPreference preference) async {
    _byThreadId[preference.threadId] = preference;
  }

  @override
  Future<void> remove(String threadId) async => _byThreadId.remove(threadId);
}
