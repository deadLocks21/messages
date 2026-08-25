import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/usecases/sync_notification_settings.usecase.dart';
import 'package:messages/core/application/usecases/update_conversation_flags.usecase.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/notifications/in_memory.notification.gateway.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';

import '../builders/builders.dart';

/// Le récepteur `SMS_DELIVER` notifie sans moteur Dart : tout ce dont il a
/// besoin doit lui avoir été poussé avant. Ces tests vérifient que ça part.
void main() {
  late InMemoryContactRepository contacts;
  late InMemoryConversationPreferencesRepository preferences;
  late InMemoryNotificationGateway gateway;
  late SyncNotificationSettingsUseCase sync;
  late UpdateConversationFlagsUseCase flags;

  setUp(() {
    contacts = InMemoryContactRepository();
    preferences = InMemoryConversationPreferencesRepository();
    gateway = InMemoryNotificationGateway();
    sync = SyncNotificationSettingsUseCase(
      directory: ContactDirectoryService(contacts),
      preferences: preferences,
      notifications: gateway,
    );
    flags = UpdateConversationFlagsUseCase(
      preferences: preferences,
      notifications: sync,
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

      expect(gateway.mutedThreads, {'42'});
    });
  });

  group('UpdateConversationFlagsUseCase', () {
    test('mettre en sourdine redescend immédiatement au natif', () async {
      await flags.toggleMuted('42');

      expect(gateway.mutedThreads, {'42'});
    });

    test('réactiver le son retire le fil de la liste', () async {
      await flags.toggleMuted('42');
      await flags.toggleMuted('42');

      expect(gateway.mutedThreads, isEmpty);
    });

    test('épingler republie la sourdine sans la modifier', () async {
      await flags.toggleMuted('42');
      await flags.togglePinned('43');

      expect(gateway.mutedThreads, {'42'});
    });
  });
}
