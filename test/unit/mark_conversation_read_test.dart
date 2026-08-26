import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/usecases/mark_conversation_read.usecase.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

void main() {
  group('MarkConversationReadUseCase', () {
    late InMemorySmsStore store;
    late MarkConversationReadUseCase usecase;

    setUp(() {
      store = InMemorySmsStore();
      usecase = MarkConversationReadUseCase(InMemoryConversationRepository(store));
    });

    test('signale un changement quand le fil avait des non-lus', () async {
      final received = store.receive(
        from: Address.parse('+33612345678'),
        body: 'Coucou',
      );

      expect(await usecase.execute(received.threadId), isTrue);
    });

    test('ne signale rien sur un fil déjà lu', () async {
      // Le cas courant : rouvrir une conversation. L'appelant s'en sert pour ne
      // pas reconstruire la liste des fils — un parcours complet du stock —
      // pendant l'animation d'ouverture.
      final threadId = store.threadIdFor([Build.address('+33612345678')]);
      store.insert(Build.message(threadId: threadId, read: true));

      expect(await usecase.execute(threadId), isFalse);
    });

    test('ne signale rien deux fois de suite', () async {
      final received = store.receive(
        from: Address.parse('+33612345678'),
        body: 'Coucou',
      );

      expect(await usecase.execute(received.threadId), isTrue);
      expect(await usecase.execute(received.threadId), isFalse);
    });
  });
}
