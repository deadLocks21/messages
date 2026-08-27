import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/usecases/delete_conversation.usecase.dart';
import 'package:messages/core/application/usecases/send_message.usecase.dart';
import 'package:messages/core/application/usecases/start_conversation.usecase.dart';
import 'package:messages/core/application/usecases/sync_notification_settings.usecase.dart';
import 'package:messages/core/application/usecases/update_conversation_flags.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/notifications/in_memory.notification.gateway.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

void main() {
  late InMemorySmsStore store;
  late InMemoryDraftRepository drafts;
  late InMemoryConversationPreferencesRepository preferences;
  late InMemoryNotificationGateway notifications;
  late SyncNotificationSettingsUseCase syncNotifications;

  setUp(() {
    store = InMemorySmsStore();
    drafts = InMemoryDraftRepository();
    preferences = InMemoryConversationPreferencesRepository();
    notifications = InMemoryNotificationGateway();
    syncNotifications = SyncNotificationSettingsUseCase(
      directory: ContactDirectoryService(
        InMemoryContactRepository(),
        logger: testLogger(),
      ),
      preferences: preferences,
      notifications: notifications,
      logger: testLogger(),
    );
  });

  tearDown(() => store.dispose());

  group('SendMessageUseCase', () {
    late SendMessageUseCase usecase;

    setUp(() {
      usecase = SendMessageUseCase(
        messages: InMemoryMessageRepository(store),
        drafts: drafts,
        configuration: InMemoryMmsConfiguration(),
        logger: testLogger(),
      );
    });

    test('envoie et rend un message en cours d\'envoi', () async {
      final sent = await usecase.execute(
        recipients: ['+33612345678'],
        body: '  Coucou  ',
      );

      // Sans pièce jointe, il n'y a rien à découper : un seul message.
      expect(sent, hasLength(1));
      expect(sent.single.body, 'Coucou');
      expect(sent.single.status, MessageStatus.sending);
      expect(sent.single.isOutgoing, isTrue);
    });

    test('efface le brouillon du fil', () async {
      final threadId = store.threadIdFor([Build.address('+33612345678')]);
      await drafts.save(threadId, 'texte en cours');

      await usecase.execute(recipients: ['+33612345678'], body: 'Coucou');

      expect(await drafts.get(threadId), isNull);
    });

    test('refuse un message vide ou sans destinataire', () async {
      expect(
        () => usecase.execute(recipients: ['+33612345678'], body: '   '),
        throwsA(isA<MessageSendFailedException>()),
      );
      expect(
        () => usecase.execute(recipients: const [], body: 'Coucou'),
        throwsA(isA<MessageSendFailedException>()),
      );
    });
  });

  group('UpdateConversationFlagsUseCase', () {
    late UpdateConversationFlagsUseCase usecase;

    setUp(
      () => usecase = UpdateConversationFlagsUseCase(
        preferences: preferences,
        notifications: syncNotifications,
        logger: testLogger(),
      ),
    );

    test('épingler puis dépingler ne laisse rien derrière', () async {
      await usecase.togglePinned('thread-1');
      expect((await preferences.listAll()).single.pinned, isTrue);

      await usecase.togglePinned('thread-1');
      expect(await preferences.listAll(), isEmpty);
    });

    test('épingler un fil archivé le sort des archives', () async {
      await usecase.toggleArchived('thread-1');
      await usecase.togglePinned('thread-1');

      final preference = (await preferences.listAll()).single;
      expect(preference.pinned, isTrue);
      expect(preference.archived, isFalse);
    });

    test('la sourdine est indépendante', () async {
      await usecase.togglePinned('thread-1');
      await usecase.toggleMuted('thread-1');

      final preference = (await preferences.listAll()).single;
      expect(preference.pinned, isTrue);
      expect(preference.muted, isTrue);
    });
  });

  group('DeleteConversationUseCase', () {
    test('supprime le fil, ses réglages et son brouillon', () async {
      final threadId = store.threadIdFor([Build.address('+33612345678')]);
      store.insert(Build.message(threadId: threadId));
      await drafts.save(threadId, 'à jeter');
      await UpdateConversationFlagsUseCase(
        preferences: preferences,
        notifications: syncNotifications,
        logger: testLogger(),
      ).togglePinned(threadId);

      await DeleteConversationUseCase(
        conversations: InMemoryConversationRepository(store),
        preferences: preferences,
        drafts: drafts,
        logger: testLogger(),
      ).execute(threadId);

      expect(store.conversations(), isEmpty);
      expect(await preferences.listAll(), isEmpty);
      expect(await drafts.get(threadId), isNull);
    });
  });

  group('StartConversationUseCase', () {
    test('rend le fil du destinataire, en le créant au besoin', () async {
      final usecase = StartConversationUseCase(
        InMemoryConversationRepository(store),
        logger: testLogger(),
      );

      final threadId = await usecase.execute(['06 12 34 56 78']);

      expect(threadId, isNotEmpty);
      expect(await usecase.execute(['+33612345678']), threadId);
    });

    test('refuse une liste sans destinataire exploitable', () {
      final usecase = StartConversationUseCase(
        InMemoryConversationRepository(store),
        logger: testLogger(),
      );

      expect(
        () => usecase.execute(const ['  ']),
        throwsA(isA<MessageSendFailedException>()),
      );
    });
  });
}
