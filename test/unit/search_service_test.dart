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

import 'package:messages/core/domain/model/enums.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

void main() {
  late InMemorySmsStore store;
  late InMemoryContactRepository contacts;
  late SearchService service;

  setUp(() {
    store = InMemorySmsStore();
    contacts = InMemoryContactRepository();
    final directory = ContactDirectoryService(contacts, logger: testLogger());
    service = SearchService(
      conversations: ConversationListService(
        conversations: InMemoryConversationRepository(store),
        directory: directory,
        preferences: InMemoryConversationPreferencesRepository(),
        drafts: InMemoryDraftRepository(),
      ),
      directory: directory,
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

  group('Recherche dans un fil', () {
    /// Deux fils qui contiennent le même mot : c'est là qu'un filtre absent
    /// se voit.
    (String, String) seedTwoThreads() {
      contacts.contacts.add(
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      );
      final camille = store.threadIdFor([Build.address('+33612345678')]);
      final autre = store.threadIdFor([Build.address('+33698765432')]);
      store.insert(
        Build.message(
          threadId: camille,
          address: '+33612345678',
          body: 'On se voit au cinéma ?',
        ),
      );
      store.insert(
        Build.message(
          threadId: autre,
          address: '+33698765432',
          body: 'Le cinéma était complet',
        ),
      );
      return (camille, autre);
    }

    test('ne rend que les messages du fil demandé', () async {
      final (camille, _) = seedTwoThreads();

      final hits = await service.searchInThread(camille, 'cinéma');

      expect(hits, hasLength(1));
      expect(hits.single.message.body, 'On se voit au cinéma ?');
    });

    test('la ligne dit qui a écrit, pas d\'où vient le message', () async {
      final (camille, _) = seedTwoThreads();
      store.insert(
        Build.message(
          threadId: camille,
          address: '+33612345678',
          direction: MessageDirection.outgoing,
          body: 'Oui, quel cinéma ?',
        ),
      );

      final hits = await service.searchInThread(camille, 'cinéma');
      final authors = hits.map((h) => h.conversationTitle).toSet();

      // Le fil est déjà choisi : ce qui reste à distinguer, c'est l'auteur.
      expect(authors, {'Camille', 'Vous'});
    });

    test('une requête trop courte ne cherche pas', () async {
      final (camille, _) = seedTwoThreads();

      expect(await service.searchInThread(camille, 'c'), isEmpty);
    });

    test('une réaction n\'est pas un résultat', () async {
      final (camille, _) = seedTwoThreads();
      store.insert(
        Build.message(
          threadId: camille,
          address: '+33612345678',
          body: 'Liked “On se voit au cinéma ?”',
        ),
      );

      // Personne n'a écrit cette phrase : elle transporte un cœur.
      final hits = await service.searchInThread(camille, 'cinéma');
      expect(hits, hasLength(1));
    });
  });
}
