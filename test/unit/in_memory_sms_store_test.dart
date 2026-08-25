import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/sms_event.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

void main() {
  late InMemorySmsStore store;

  setUp(() => store = InMemorySmsStore());
  tearDown(() => store.dispose());

  group('InMemorySmsStore', () {
    test('un jeu de destinataires garde le même thread_id', () {
      final first = store.threadIdFor([Build.address('+33612345678')]);
      final again = store.threadIdFor([Build.address('0612345678')]);
      final other = store.threadIdFor([Build.address('0698765432')]);

      expect(again, first);
      expect(other, isNot(first));
    });

    test('les fils sont dérivés des messages, du plus récent au plus ancien', () {
      final ancien = store.threadIdFor([Build.address('+33612345678')]);
      final recent = store.threadIdFor([Build.address('+33698765432')]);
      store.insert(
        Build.message(threadId: ancien, sentAt: DateTime(2026, 8, 20, 9)),
      );
      store.insert(
        Build.message(
          threadId: recent,
          address: '+33698765432',
          body: 'Dernier',
          sentAt: DateTime(2026, 8, 25, 9),
        ),
      );

      final conversations = store.conversations();

      expect(conversations.map((c) => c.id), [recent, ancien]);
      expect(conversations.first.snippet, 'Dernier');
      expect(conversations.first.messageCount, 1);
    });

    test('un entrant non lu compte, un sortant jamais', () {
      final threadId = store.threadIdFor([Build.address('+33612345678')]);
      store.insert(Build.message(threadId: threadId, read: false));
      store.insert(
        Build.message(
          threadId: threadId,
          direction: MessageDirection.outgoing,
          read: false,
        ),
      );

      expect(store.conversations().single.unreadCount, 1);
    });

    test('recevoir un SMS publie un événement', () async {
      final events = <SmsEvent>[];
      final subscription = store.events.listen(events.add);

      store.receive(from: Address.parse('+33612345678'), body: 'Salut');
      await Future<void>.delayed(Duration.zero);

      expect(events.single, isA<MessageReceived>());
      expect((events.single as MessageReceived).message.body, 'Salut');
      await subscription.cancel();
    });

    test('marquer lu vide le compteur et publie un changement', () async {
      final events = <SmsEvent>[];
      final subscription = store.events.listen(events.add);
      final received = store.receive(
        from: Address.parse('+33612345678'),
        body: 'Salut',
      );

      store.markThreadRead(received.threadId);
      await Future<void>.delayed(Duration.zero);

      expect(store.conversations().single.unreadCount, 0);
      expect(events.last, isA<StoreChanged>());
      await subscription.cancel();
    });

    test('un envoi part en « envoi en cours »', () {
      final sent = store.send(
        recipients: [Build.address('+33612345678')],
        body: 'Yo',
      );

      expect(sent.status, MessageStatus.sending);
      expect(sent.direction, MessageDirection.outgoing);
      expect(store.messagesFor(sent.threadId).single.body, 'Yo');
    });

    test('supprimer un fil efface ses messages', () {
      final sent = store.send(
        recipients: [Build.address('+33612345678')],
        body: 'Yo',
      );

      store.deleteThread(sent.threadId);

      expect(store.conversations(), isEmpty);
      expect(store.messagesFor(sent.threadId), isEmpty);
    });
  });
}
