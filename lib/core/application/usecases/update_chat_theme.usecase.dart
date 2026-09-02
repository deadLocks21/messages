import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';

/// Le thème d'une discussion : une graine de couleur, un fond d'écran, ou
/// aucun des deux.
///
/// Séparé de [UpdateConversationFlagsUseCase] pour une raison précise : celui-ci
/// republie les fils en sourdine à chaque écriture, parce que le récepteur en a
/// besoin. Le thème, lui, ne regarde que l'écran — republier une liste de
/// sourdines pour un changement de couleur serait du travail pour personne.
class UpdateChatThemeUseCase {
  final ConversationPreferencesRepository _preferences;
  final LoggerApplicationService _logger;

  const UpdateChatThemeUseCase({
    required ConversationPreferencesRepository preferences,
    required LoggerApplicationService logger,
  }) : _preferences = preferences,
       _logger = logger;

  /// Pose une couleur. Le fond d'écran, s'il y en a un, reste.
  Future<void> setSeed(String threadId, int seed) =>
      _update(threadId, (p) => p.copyWith(themeSeed: seed));

  /// Pose un fond d'écran. La couleur, s'il y en a une, reste.
  Future<void> setWallpaper(String threadId, String path) =>
      _update(threadId, (p) => p.copyWith(wallpaperPath: path));

  /// Rend le fil au thème de l'appareil.
  Future<void> reset(String threadId) =>
      _update(threadId, (p) => p.copyWith(clearTheme: true));

  Future<void> _update(
    String threadId,
    ConversationPreference Function(ConversationPreference) change,
  ) async {
    final current =
        (await _preferences.listAll())
            .where((p) => p.threadId == threadId)
            .firstOrNull ??
        ConversationPreference.none(threadId);
    final updated = change(current);
    if (updated.isDefault) {
      await _preferences.remove(threadId);
    } else {
      await _preferences.save(updated);
    }
    await _logger.info(
      'conversation.theme_changed',
      attrs: {
        'thread.id': threadId,
        'theme.seed': ?updated.themeSeed,
        'theme.has_wallpaper': updated.wallpaperPath != null,
      },
    );
  }
}
