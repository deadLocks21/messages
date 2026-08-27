import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/domain/services/notification.gateway.dart';

/// Tient à jour ce que la plateforme doit savoir pour notifier correctement :
/// qui est en sourdine, et comment s'appellent les numéros.
///
/// Le récepteur `SMS_DELIVER` s'exécute souvent **sans moteur Dart** — il ne
/// peut donc rien demander à l'app au moment où il notifie. Tout doit lui avoir
/// été poussé avant.
///
/// Chaque publication laisse une trace de ce que le natif a réellement reçu.
/// Une notification qui affiche un numéro nu au lieu d'un nom, ou qui sonne
/// pour un fil mis en sourdine, se lit **là** : soit la publication n'a pas eu
/// lieu, soit elle était vide.
class SyncNotificationSettingsUseCase {
  final ContactDirectoryService _directory;
  final ConversationPreferencesRepository _preferences;
  final NotificationGateway _notifications;
  final LoggerApplicationService _logger;

  const SyncNotificationSettingsUseCase({
    required ContactDirectoryService directory,
    required ConversationPreferencesRepository preferences,
    required NotificationGateway notifications,
    required LoggerApplicationService logger,
  }) : _directory = directory,
       _preferences = preferences,
       _notifications = notifications,
       _logger = logger;

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
    await _logger.debug(
      'notifications.muted_published',
      attrs: {'threads.muted': muted.length},
    );
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
    await _logger.info(
      'notifications.directory_published',
      attrs: {
        'contacts.count': directory.all.length,
        'addresses.count': names.length,
      },
    );
  }
}
