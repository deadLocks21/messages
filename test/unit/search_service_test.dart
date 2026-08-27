import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/core/application/services/search.service.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

void main() {
  late InMemorySmsStore store;
  late InMemoryContactRepository contacts;
  late SearchService service;

  setUp(() {
    store = InMemorySmsStore();
    contacts = InMemoryContactRepository();
    service = SearchService(
      conversations: ConversationListService(
        conversations: InMemoryConversationRepository(store),
        directory: ContactDirectoryService(contacts, logger: testLogger()),
        preferences: InMemoryConversationPreferencesRepository(),
        drafts: InMemoryDraftRepository(),
      ),
      messages: InMemoryMessageRepository(store),
    );
  });

  tearDown(() => store.dispose());

  void seed() {
    contacts.contacts.add(
      Build.contact(displayName: 'Camille', addresses: ['0612345678']),
    );
    final threadId = store.threadIdFor([Build.address('+33612345678')]);
    store.insert(
      Build.message(threadId: threadId, body: 'Rendez-vous au cinéma à 20h'),
    );
  }

  group('SearchService', () {
    test('ignore une requête trop courte', () async {
      seed();

      expect((await service.search('c')).isEmpty, isTrue);
    });

    test('trouve un fil par le nom du contact', () async {
      seed();

      final results = await service.search('cami');

      expect(results.conversations.single.title, 'Camille');
    });

    test('trouve un fil par son numéro, quelle que soit la forme', () async {
      seed();

      final results = await service.search('06 12 34');

      expect(results.conversations, hasLength(1));
    });

    test('trouve un message par son texte et le rattache à son fil', () async {
      seed();

      final results = await service.search('cinéma');

      expect(results.messages.single.conversationTitle, 'Camille');
      expect(results.messages.single.message.body, contains('cinéma'));
    });

    test('rend un résultat vide quand rien ne correspond', () async {
      seed();

      expect((await service.search('zzzz')).isEmpty, isTrue);
    });
  });
}
