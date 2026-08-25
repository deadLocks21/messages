import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/application/usecases/sync_notification_settings.usecase.dart';

/// Bascule les réglages locaux d'un fil : épinglé, archivé, en sourdine.
///
/// Épingler un fil archivé le désarchive : les deux états s'excluent dans l'UI
/// de Google Messages (un fil épinglé est en tête de la liste principale).
///
/// Toute modification republie l'ensemble des fils en sourdine vers la
/// plateforme : c'est le récepteur `SMS_DELIVER` qui décide de notifier ou non,
/// et il ne peut pas interroger Dart au moment où il s'exécute.
class UpdateConversationFlagsUseCase {
  final ConversationPreferencesRepository _preferences;
  final SyncNotificationSettingsUseCase _notifications;

  const UpdateConversationFlagsUseCase({
    required ConversationPreferencesRepository preferences,
    required SyncNotificationSettingsUseCase notifications,
  }) : _preferences = preferences,
       _notifications = notifications;

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
    } else {
      await _preferences.save(updated);
    }
    await _notifications.publishMutedThreads();
  }
}
