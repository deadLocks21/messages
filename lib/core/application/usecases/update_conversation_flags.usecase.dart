import 'package:messages/core/application/services/logger_application.service.dart';
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
  final LoggerApplicationService _logger;
  final DateTime Function() _clock;

  const UpdateConversationFlagsUseCase({
    required ConversationPreferencesRepository preferences,
    required SyncNotificationSettingsUseCase notifications,
    required LoggerApplicationService logger,

    /// L'heure, injectable : une mise en veille est une date, et un test qui
    /// ne peut pas la choisir ne peut pas vérifier qu'elle expire.
    DateTime Function() clock = DateTime.now,
  }) : _preferences = preferences,
       _notifications = notifications,
       _logger = logger,
       _clock = clock;

  Future<void> togglePinned(String threadId) =>
      _update(threadId, (p) => p.copyWith(pinned: !p.pinned, archived: false));

  Future<void> toggleArchived(String threadId) =>
      _update(threadId, (p) => p.copyWith(archived: !p.archived, pinned: false));

  Future<void> toggleMuted(String threadId) =>
      _update(threadId, (p) => p.copyWith(muted: !p.muted, clearSnooze: true));

  /// Met le fil en veille pour [duration], ou **sans fin** si elle est nulle —
  /// le « Toujours » du dialogue, qui est exactement la sourdine.
  ///
  /// Les deux s'excluent : une veille à échéance efface la sourdine, et
  /// inversement. Sans quoi un fil pourrait être en veille jusqu'à 18 h *et*
  /// en sourdine pour toujours, et l'écran ne saurait quoi en dire.
  Future<void> snooze(String threadId, Duration? duration) => _update(
    threadId,
    (p) => duration == null
        ? p.copyWith(muted: true, clearSnooze: true)
        : p.copyWith(muted: false, snoozedUntil: _clock().add(duration)),
  );

  /// Réveille le fil, qu'il ait été mis en veille ou en sourdine.
  Future<void> wake(String threadId) =>
      _update(threadId, (p) => p.copyWith(muted: false, clearSnooze: true));

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
    // L'état final, pas le geste : « a basculé la sourdine » ne dit pas dans
    // quel sens, et c'est le sens qui explique la notification suivante.
    await _logger.info(
      'conversation.flags_changed',
      attrs: {
        'thread.id': threadId,
        'thread.pinned': updated.pinned,
        'thread.archived': updated.archived,
        'thread.muted': updated.muted,
        'thread.snoozed_until': ?updated.snoozedUntil?.toIso8601String(),
      },
    );
  }
}
