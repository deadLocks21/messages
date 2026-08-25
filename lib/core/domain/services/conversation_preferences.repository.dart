import 'package:messages/core/domain/model/conversation_preference.dart';

/// Port des réglages de fil propres à l'app (épinglé / archivé / en sourdine).
abstract interface class ConversationPreferencesRepository {
  /// Réglages de tous les fils qui en ont. Les fils absents sont par défaut.
  Future<List<ConversationPreference>> listAll();

  Future<void> save(ConversationPreference preference);

  /// Oublie les réglages d'un fil supprimé.
  Future<void> remove(String threadId);
}
