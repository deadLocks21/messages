import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/domain/services/notification.gateway.dart';

/// Tient à jour ce que la plateforme doit savoir pour notifier correctement :
/// qui est en sourdine, et comment s'appellent les numéros.
///
/// Le récepteur `SMS_DELIVER` s'exécute souvent **sans moteur Dart** — il ne
/// peut donc rien demander à l'app au moment où il notifie. Tout doit lui avoir
/// été poussé avant.
class SyncNotificationSettingsUseCase {
  final ContactDirectoryService _directory;
  final ConversationPreferencesRepository _preferences;
  final NotificationGateway _notifications;

  const SyncNotificationSettingsUseCase({
    required ContactDirectoryService directory,
    required ConversationPreferencesRepository preferences,
    required NotificationGateway notifications,
  }) : _directory = directory,
       _preferences = preferences,
       _notifications = notifications;

  /// Tout republier. Appelé au démarrage et à chaque retour au premier plan :
  /// un contact ajouté ou renommé pendant que l'app dormait doit être nommé
  /// correctement à la prochaine notification.
  Future<void> execute() async {
    await publishMutedThreads();
    await _publishDirectory();
  }

  /// Ne republier que les fils en sourdine — le cas d'un simple basculement,
  /// qui n'a aucune raison de relire tout le carnet d'adresses.
  Future<void> publishMutedThreads() async {
    final muted = (await _preferences.listAll())
        .where((p) => p.muted)
        .map((p) => p.threadId)
        .toSet();
    await _notifications.setMutedThreads(muted);
  }

  Future<void> _publishDirectory() async {
    final directory = await _directory.load();
    final names = <String, String>{};
    for (final contact in directory.all) {
      for (final address in contact.addresses) {
        // Premier arrivé, premier servi — même règle que l'annuaire lui-même.
        names.putIfAbsent(address.key, () => contact.displayName);
      }
    }
    await _notifications.setDirectory(names);
  }
}
