import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_timeline.service.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

/// Le repli vu depuis le fil : ce que l'écran affiche une fois les réactions
/// retirées des bulles. C'est le comportement qui compte — le codec, lui, est
/// testé phrase par phrase dans `reaction_codec_test.dart`.
void main() {
  late InMemorySmsStore store;
  late ConversationTimelineService service;

  setUp(() {
    store = InMemorySmsStore();
    service = ConversationTimelineService(
      messages: InMemoryMessageRepository(store),
      directory: ContactDirectoryService(
        InMemoryContactRepository(),
        logger: testLogger(),
      ),
    );
  });

  tearDown(() => store.dispose());

  List<TimelineMessage> bubblesOf(ConversationTimelineDto timeline) =>
      timeline.entries.whereType<TimelineMessage>().toList();

  group('Réactions reçues', () {
    test('un tapback d\'iPhone se pose sur la bulle qu\'il cite', () async {
      store.insert(
        Build.message(
          id: 'm1',
          body: 'On se voit demain ?',
          direction: MessageDirection.outgoing,
          sentAt: DateTime(2026, 8, 25, 10, 0),
        ),
      );
      store.insert(
        Build.message(
          body: 'Liked “On se voit demain ?”',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.id, 'm1');
      expect(bubbles.single.message.reactions.single.emoji, '👍');
      expect(bubbles.single.message.reactions.single.isMine, isFalse);
    });

    test('la réaction d\'un Google Messages se pose sur la bulle', () async {
      // Le message tel qu'il arrive vraiment : emoji encadré d'espaces de
      // largeur nulle, citation entre guillemets droits doublés d'espaces fins.
      store.insert(
        Build.message(
          id: 'm1',
          body: 'J\'ai besoin du code stp',
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          body:
              '\u200a\u200b\u{1F44D}\u200b à "\u200aJ\'ai besoin du code stp\u200a"\u200a',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.id, 'm1');
      expect(bubbles.single.message.reactions.single.emoji, '👍');
    });

    test('une citation coupée retrouve son message', () async {
      final long = 'Je te raconte : ${'x' * 200} et voilà';
      store.insert(
        Build.message(
          id: 'm1',
          body: long,
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          body: ReactionCodec.encode(emoji: '😂', target: long),
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.reactions.single.emoji, '😂');
    });

    test('une réaction sans cible reste le message qu\'elle est', () async {
      store.insert(Build.message(id: 'm1', body: 'Bonjour'));
      store.insert(
        Build.message(
          body: 'Liked “un message qui n\'existe pas”',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 2);
      expect(bubbles.last.message.body, startsWith('Liked'));
    });

    test('la réaction la plus récente de la même personne remplace l\'autre', () async {
      store.insert(
        Build.message(
          id: 'm1',
          body: 'Bonjour',
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          body: 'Liked “Bonjour”',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );
      store.insert(
        Build.message(
          body: 'Laughed at “Bonjour”',
          sentAt: DateTime(2026, 8, 25, 10, 2),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.reactions.map((r) => r.emoji), ['😂']);
    });

    test('un retrait décroche la réaction', () async {
      store.insert(
        Build.message(
          id: 'm1',
          body: 'Bonjour',
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          body: 'Loved “Bonjour”',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );
      store.insert(
        Build.message(
          body: 'Removed a heart from “Bonjour”',
          sentAt: DateTime(2026, 8, 25, 10, 2),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.reactions, isEmpty);
    });

    test('deux personnes d\'un groupe réagissent chacune', () async {
      store.insert(
        Build.message(
          id: 'm1',
          address: '+33612345678',
          body: 'Bonjour',
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          address: '+33612345678',
          body: 'Liked “Bonjour”',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );
      store.insert(
        Build.message(
          address: '+33623456789',
          body: 'Liked “Bonjour”',
          sentAt: DateTime(2026, 8, 25, 10, 2),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.reactions.single.count, 2);
    });

    test('une réaction à une photo se pose sur la photo', () async {
      store.insert(
        Build.message(
          id: 'm1',
          body: '',
          direction: MessageDirection.outgoing,
          attachments: [Build.attachment(mimeType: 'image/jpeg')],
        ),
      );
      store.insert(
        Build.message(
          body: 'Liked an image',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.reactions.single.emoji, '👍');
    });
  });

  group('Réactions envoyées', () {
    test('la nôtre se pose sur la bulle et se sait nôtre', () async {
      store.insert(Build.message(id: 'm1', body: 'Bonjour'));
      store.insert(
        Build.message(
          body: 'Loved “Bonjour”',
          direction: MessageDirection.outgoing,
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 1);
      expect(bubbles.single.message.reactions.single.isMine, isTrue);
      expect(bubbles.single.message.myReaction, '😍');
    });

    test('une réaction en échec garde sa bulle et son état', () async {
      store.insert(Build.message(id: 'm1', body: 'Bonjour'));
      store.insert(
        Build.message(
          body: 'Loved “Bonjour”',
          direction: MessageDirection.outgoing,
          status: MessageStatus.failed,
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.length, 2);
      expect(bubbles.last.message.status, MessageStatus.failed);
    });

    test('l\'état du dernier envoi ne disparaît pas sous une réaction', () async {
      store.insert(
        Build.message(
          id: 'm1',
          body: 'Bonjour',
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          body: 'Coucou',
          sentAt: DateTime(2026, 8, 25, 10, 1),
        ),
      );
      store.insert(
        Build.message(
          body: 'Liked “Coucou”',
          direction: MessageDirection.outgoing,
          sentAt: DateTime(2026, 8, 25, 10, 2),
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.map((b) => b.showStatus), [true, false]);
    });
  });

  test('le repli désactivé rend le fil tel qu\'il est dans le stock', () async {
    store.insert(Build.message(id: 'm1', body: 'Bonjour'));
    store.insert(
      Build.message(
        body: 'Liked “Bonjour”',
        sentAt: DateTime(2026, 8, 25, 10, 1),
      ),
    );

    final bubbles = bubblesOf(
      await service.build('thread-1', foldReactions: false),
    );

    expect(bubbles.length, 2);
    expect(bubbles.last.message.reactions, isEmpty);
  });
}
