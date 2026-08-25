import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

void main() {
  late InMemorySmsStore store;
  late InMemoryContactRepository contacts;
  late InMemoryConversationPreferencesRepository preferences;
  late InMemoryDraftRepository drafts;
  late ConversationListService service;

  setUp(() {
    store = InMemorySmsStore();
    contacts = InMemoryContactRepository();
    preferences = InMemoryConversationPreferencesRepository();
    drafts = InMemoryDraftRepository();
    service = ConversationListService(
      conversations: InMemoryConversationRepository(store),
      directory: ContactDirectoryService(contacts),
      preferences: preferences,
      drafts: drafts,
    );
  });

  tearDown(() => store.dispose());

  /// Crée un fil daté avec un unique message entrant.
  String seedThread(String address, DateTime at, {bool read = true}) {
    final threadId = store.threadIdFor([Build.address(address)]);
    store.insert(
      Build.message(
        threadId: threadId,
        address: address,
        sentAt: at,
        read: read,
      ),
    );
    return threadId;
  }

  group('ConversationListService', () {
    test('nomme les fils avec le carnet d\'adresses', () async {
      contacts.contacts.add(
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      );
      seedThread('+33612345678', DateTime(2026, 8, 25, 10));

      final items = await service.list();

      expect(items.single.title, 'Camille');
    });

    test('retombe sur le numéro formaté sans contact', () async {
      seedThread('+33612345678', DateTime(2026, 8, 25, 10));

      final items = await service.list();

      expect(items.single.title, '06 12 34 56 78');
    });

    test('trie les épinglés en tête, puis par date décroissante', () async {
      final vieux = seedThread('0611111111', DateTime(2026, 8, 20, 9));
      seedThread('0622222222', DateTime(2026, 8, 25, 9));
      await preferences.save(
        ConversationPreference(threadId: vieux, pinned: true),
      );

      final items = await service.list();

      expect(items.first.threadId, vieux);
      expect(items.first.isPinned, isTrue);
    });

    test('les archivés quittent la liste principale', () async {
      final archived = seedThread('0611111111', DateTime(2026, 8, 20, 9));
      seedThread('0622222222', DateTime(2026, 8, 25, 9));
      await preferences.save(
        ConversationPreference(threadId: archived, archived: true),
      );

      final principale = await service.list();
      final archives = await service.list(filter: ConversationFilter.archived);

      expect(principale.map((c) => c.threadId), isNot(contains(archived)));
      expect(archives.single.threadId, archived);
    });

    test('le filtre « non lus » ne garde que les fils à lire', () async {
      seedThread('0611111111', DateTime(2026, 8, 20, 9));
      final nonLu = seedThread('0622222222', DateTime(2026, 8, 25, 9), read: false);

      final items = await service.list(filter: ConversationFilter.unread);

      expect(items.single.threadId, nonLu);
      expect(await service.unreadCount(), 1);
    });

    test('remonte le brouillon du fil', () async {
      final threadId = seedThread('0611111111', DateTime(2026, 8, 25, 9));
      await drafts.save(threadId, 'à demain');

      final items = await service.list();

      expect(items.single.hasDraft, isTrue);
      expect(items.single.draft, 'à demain');
    });

    test('prévisualise un fil qui n\'existe pas encore', () async {
      contacts.contacts.add(
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      );

      final preview = await service.previewFor([Build.address('+33612345678')]);

      expect(preview.threadId, '');
      expect(preview.title, 'Camille');
      expect(preview.isGroup, isFalse);
    });
  });
}
