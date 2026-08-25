import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';

/// Bascule les réglages locaux d'un fil : épinglé, archivé, en sourdine.
///
/// Épingler un fil archivé le désarchive : les deux états s'excluent dans l'UI
/// de Google Messages (un fil épinglé est en tête de la liste principale).
class UpdateConversationFlagsUseCase {
  final ConversationPreferencesRepository _preferences;

  const UpdateConversationFlagsUseCase(this._preferences);

  Future<void> togglePinned(String threadId) =>
      _update(threadId, (p) => p.copyWith(pinned: !p.pinned, archived: false));

  Future<void> toggleArchived(String threadId) =>
      _update(threadId, (p) => p.copyWith(archived: !p.archived, pinned: false));

  Future<void> toggleMuted(String threadId) =>
      _update(threadId, (p) => p.copyWith(muted: !p.muted));

  Future<void> _update(
    String threadId,
    ConversationPreference Function(ConversationPreference) change,
  ) async {
    final current = (await _preferences.listAll())
            .where((p) => p.threadId == threadId)
            .firstOrNull ??
        ConversationPreference.none(threadId);
    final updated = change(current);
    if (updated.isDefault) {
      await _preferences.remove(threadId);
      return;
    }
    await _preferences.save(updated);
  }
}
