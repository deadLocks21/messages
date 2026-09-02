import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_details.service.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

void main() {
  late InMemorySmsStore store;
  late InMemoryContactRepository contacts;
  late ConversationDetailsService service;

  setUp(() {
    store = InMemorySmsStore();
    contacts = InMemoryContactRepository();
    final directory = ContactDirectoryService(contacts, logger: testLogger());
    service = ConversationDetailsService(
      conversations: ConversationListService(
        conversations: InMemoryConversationRepository(store),
        directory: directory,
        preferences: InMemoryConversationPreferencesRepository(),
        drafts: InMemoryDraftRepository(),
      ),
      directory: directory,
    );
  });

  tearDown(() => store.dispose());

  String seedThread(List<String> addresses) {
    final threadId = store.threadIdFor(addresses.map(Build.address).toList());
    store.insert(
      Build.message(threadId: threadId, address: addresses.first),
    );
    return threadId;
  }

  test('un numéro du carnet porte son nom, son numéro et sa fiche', () async {
    contacts.contacts.add(
      Build.contact(
        id: 'contact-camille',
        displayName: 'Camille',
        addresses: ['0612345678'],
      ),
    );
    final threadId = seedThread(['+33612345678']);

    final details = await service.byId(threadId);

    final participant = details!.soleParticipant!;
    expect(participant.displayName, 'Camille');
    expect(participant.addressLabel, '06 12 34 56 78');
    // C'est la forme brute du stock qui part au composeur d'appel et au
    // carnet, pas celle qu'on affiche.
    expect(participant.rawAddress, '+33612345678');
    expect(participant.contactId, 'contact-camille');
    expect(participant.isKnown, isTrue);
  });

  test('un numéro sans fiche est son propre nom, et n\'a pas de sous-titre', () async {
    final threadId = seedThread(['+33612345678']);

    final participant = (await service.byId(threadId))!.soleParticipant!;

    expect(participant.displayName, '06 12 34 56 78');
    // La ligne du dessous répéterait le titre : l'app d'origine ne l'écrit
    // qu'une fois.
    expect(participant.addressLabel, isEmpty);
    expect(participant.isKnown, isFalse);
  });

  test('un fil de groupe n\'a pas d\'interlocuteur unique', () async {
    final threadId = seedThread(['+33612345678', '+33698765432']);

    final details = await service.byId(threadId);

    expect(details!.participants, hasLength(2));
    expect(details.soleParticipant, isNull);
  });

  test('un fil supprimé entre-temps ne rend rien', () async {
    expect(await service.byId('thread-disparu'), isNull);
  });
}
