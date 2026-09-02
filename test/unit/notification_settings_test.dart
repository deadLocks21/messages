import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/usecases/sync_notification_settings.usecase.dart';
import 'package:messages/core/application/usecases/update_conversation_flags.usecase.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/notifications/in_memory.notification.gateway.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

/// Le récepteur `SMS_DELIVER` notifie sans moteur Dart : tout ce dont il a
/// besoin doit lui avoir été poussé avant. Ces tests vérifient que ça part.
void main() {
  /// Une horloge qu'on avance à la main : une veille est une date, et un test
  /// qui ne peut pas la choisir ne peut pas la voir expirer.
  late DateTime now;
  late InMemoryContactRepository contacts;
  late InMemoryConversationPreferencesRepository preferences;
  late InMemoryNotificationGateway gateway;
  late SyncNotificationSettingsUseCase sync;
  late UpdateConversationFlagsUseCase flags;

  setUp(() {
    now = DateTime(2026, 9, 2, 10);
    contacts = InMemoryContactRepository();
    preferences = InMemoryConversationPreferencesRepository();
    gateway = InMemoryNotificationGateway();
    sync = SyncNotificationSettingsUseCase(
      directory: ContactDirectoryService(contacts, logger: testLogger()),
      preferences: preferences,
      notifications: gateway,
      logger: testLogger(),
      clock: () => now,
    );
    flags = UpdateConversationFlagsUseCase(
      preferences: preferences,
      notifications: sync,
      logger: testLogger(),
      clock: () => now,
    );
  });

  group('SyncNotificationSettingsUseCase', () {
    test('publie l\'annuaire indexé par clé d\'adresse', () async {
      contacts.contacts.add(
        Build.contact(displayName: 'Camille', addresses: ['+33612345678']),
      );

      await sync.execute();

      // La clé est celle d'`Address` : le natif la recalcule à l'identique.
      expect(gateway.directory, {'612345678': 'Camille'});
    });

    test('un contact à plusieurs numéros est nommé sur chacun', () async {
      contacts.contacts.add(
        Build.contact(
          displayName: 'Camille',
          addresses: ['+33612345678', '0198765432'],
        ),
      );

      await sync.execute();

      expect(gateway.directory.values.toSet(), {'Camille'});
      expect(gateway.directory, hasLength(2));
    });

    test('publie les fils en sourdine', () async {
      await flags.toggleMuted('42');

      await sync.execute();

      expect(gateway.mutedThreads, {'42': null});
    });
  });

  group('UpdateConversationFlagsUseCase', () {
    test('mettre en sourdine redescend immédiatement au natif', () async {
      await flags.toggleMuted('42');

      expect(gateway.mutedThreads, {'42': null});
    });

    test('réactiver le son retire le fil de la liste', () async {
      await flags.toggleMuted('42');
      await flags.toggleMuted('42');

      expect(gateway.mutedThreads, isEmpty);
    });

    test('épingler republie la sourdine sans la modifier', () async {
      await flags.toggleMuted('42');
      await flags.togglePinned('43');

      expect(gateway.mutedThreads, {'42': null});
    });
  });

  group('Mise en veille', () {
    test('une veille part au natif avec son échéance', () async {
      await flags.snooze('42', const Duration(hours: 8));

      expect(gateway.mutedThreads, {'42': DateTime(2026, 9, 2, 18)});
    });

    test('« Toujours » est la sourdine, sans échéance', () async {
      await flags.snooze('42', null);

      expect(gateway.mutedThreads, {'42': null});
      final preference = (await preferences.listAll()).single;
      expect(preference.muted, isTrue);
      expect(preference.snoozedUntil, isNull);
    });

    test('une veille échue ne coupe plus rien et n\'est plus publiée', () async {
      await flags.snooze('42', const Duration(hours: 1));
      expect(gateway.mutedThreads, hasLength(1));

      // Deux heures plus tard, le réglage est toujours en base — c'est
      // l'échéance qui décide, pas un nettoyage.
      now = DateTime(2026, 9, 2, 12);
      await sync.publishMutedThreads();

      expect(gateway.mutedThreads, isEmpty);
      expect(await preferences.listAll(), hasLength(1));
    });

    test('réveiller un fil efface veille et sourdine', () async {
      await flags.snooze('42', const Duration(hours: 8));
      await flags.wake('42');

      expect(gateway.mutedThreads, isEmpty);
      // Plus rien à persister : le fil est rendu à son état par défaut.
      expect(await preferences.listAll(), isEmpty);
    });

    test('la sourdine efface une veille en cours, et l\'inverse', () async {
      await flags.snooze('42', const Duration(hours: 8));
      await flags.toggleMuted('42');
      expect((await preferences.listAll()).single.snoozedUntil, isNull);

      await flags.snooze('42', const Duration(hours: 1));
      final preference = (await preferences.listAll()).single;
      expect(preference.muted, isFalse);
      expect(preference.snoozedUntil, DateTime(2026, 9, 2, 11));
    });
  });
}
