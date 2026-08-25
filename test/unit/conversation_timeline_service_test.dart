import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_timeline.service.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

void main() {
  late InMemorySmsStore store;
  late ConversationTimelineService service;

  setUp(() {
    store = InMemorySmsStore();
    service = ConversationTimelineService(
      messages: InMemoryMessageRepository(store),
      directory: ContactDirectoryService(InMemoryContactRepository()),
    );
  });

  tearDown(() => store.dispose());

  List<TimelineMessage> bubblesOf(ConversationTimelineDto timeline) =>
      timeline.entries.whereType<TimelineMessage>().toList();

  group('ConversationTimelineService', () {
    test('un fil vide n\'a aucune entrée', () async {
      final timeline = await service.build('thread-1');

      expect(timeline.isEmpty, isTrue);
    });

    test('groupe les messages rapprochés du même interlocuteur', () async {
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 0)));
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 2)));
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 3)));

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.map((b) => b.isFirstOfGroup), [true, false, false]);
      expect(bubbles.map((b) => b.isLastOfGroup), [false, false, true]);
    });

    test('un changement de sens ouvre un nouveau groupe', () async {
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 0)));
      store.insert(
        Build.message(
          sentAt: DateTime(2026, 8, 25, 10, 1),
          direction: MessageDirection.outgoing,
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.every((b) => b.isFirstOfGroup && b.isLastOfGroup), isTrue);
    });

    test('un séparateur ouvre le fil et marque chaque changement de jour', () async {
      store.insert(Build.message(sentAt: DateTime(2026, 8, 24, 10, 0)));
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 0)));

      final timeline = await service.build('thread-1');

      expect(timeline.entries.whereType<TimelineSeparator>().length, 2);
      expect(timeline.entries.first, isA<TimelineSeparator>());
    });

    test('plus d\'une heure de silence réaffiche l\'heure', () async {
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 0)));
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 12, 0)));

      final timeline = await service.build('thread-1');

      expect(timeline.entries.whereType<TimelineSeparator>().length, 2);
    });

    test('seul le dernier sortant porte son état', () async {
      store.insert(
        Build.message(
          sentAt: DateTime(2026, 8, 25, 10, 0),
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          sentAt: DateTime(2026, 8, 25, 10, 1),
          direction: MessageDirection.outgoing,
          status: MessageStatus.delivered,
        ),
      );
      store.insert(Build.message(sentAt: DateTime(2026, 8, 25, 10, 2)));

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.where((b) => b.showStatus).length, 1);
      expect(bubbles.where((b) => b.showStatus).single.message.statusLabel, 'Distribué');
    });

    test('un échec garde sa propre bulle', () async {
      store.insert(
        Build.message(
          sentAt: DateTime(2026, 8, 25, 10, 0),
          direction: MessageDirection.outgoing,
        ),
      );
      store.insert(
        Build.message(
          sentAt: DateTime(2026, 8, 25, 10, 1),
          direction: MessageDirection.outgoing,
          status: MessageStatus.failed,
        ),
      );

      final bubbles = bubblesOf(await service.build('thread-1'));

      expect(bubbles.last.isFirstOfGroup, isTrue);
    });
  });
}
