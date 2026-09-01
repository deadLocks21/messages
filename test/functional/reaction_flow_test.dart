import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversations/conversations.page.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

/// Réagir, de bout en bout : le geste, le SMS qui part, et la pastille qui
/// revient du stock.
void main() {
  (TestDevice, String) deviceWithThread() {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(threadId: threadId, body: 'Tu es dispo ce soir ?'),
    );
    return (device, threadId);
  }

  testWidgets('réagir envoie un SMS au format des tapbacks iPhone', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    final message = device.store.messagesFor(threadId).single;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.longPress(find.byKey(Key('bubble_${message.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('react_👍')));
    await tester.pumpAndSettle();

    final sent = device.store
        .messagesFor(threadId)
        .firstWhere((m) => m.direction == MessageDirection.outgoing);
    expect(sent.body, 'Liked “Tu es dispo ce soir ?”');
  });

  testWidgets('la réaction envoyée se pose sur la bulle, sans en créer une', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    final message = device.store.messagesFor(threadId).single;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.longPress(find.byKey(Key('bubble_${message.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('react_😂')));
    await tester.pumpAndSettle();

    // Deux messages dans le stock, une seule bulle à l'écran.
    expect(device.store.messagesFor(threadId).length, 2);
    expect(find.byKey(Key('reaction_${message.id}_😂')), findsOneWidget);
    expect(find.textContaining('Laughed at'), findsNothing);
  });

  testWidgets('toucher à nouveau son emoji envoie le retrait', (tester) async {
    final (device, threadId) = deviceWithThread();
    final message = device.store.messagesFor(threadId).single;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.longPress(find.byKey(Key('bubble_${message.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('react_😍')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(Key('bubble_${message.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('react_😍')));
    await tester.pumpAndSettle();

    final outgoing = device.store
        .messagesFor(threadId)
        .where((m) => m.direction == MessageDirection.outgoing)
        .toList();
    expect(outgoing.length, 2);
    expect(outgoing.last.body, 'Removed a heart from “Tu es dispo ce soir ?”');
    expect(find.byKey(Key('reaction_${message.id}_😍')), findsNothing);
  });

  testWidgets('un tapback reçu d\'un iPhone s\'affiche sur la bulle citée', (
    tester,
  ) async {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    final mine = Build.message(
      threadId: threadId,
      body: 'Rendez-vous à 18h',
      direction: MessageDirection.outgoing,
    );
    device.store.insert(mine);

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    device.store.receive(
      from: Address.parse('+33612345678'),
      body: 'Loved “Rendez-vous à 18h”',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(Key('reaction_${mine.id}_😍')), findsOneWidget);
    expect(find.textContaining('Loved'), findsNothing);
  });

  testWidgets('la liste des fils annonce la réaction, pas la phrase anglaise', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.store.receive(
      from: Address.parse('+33612345678'),
      body: 'Liked “Tu es dispo ce soir ?”',
    );

    await pumpPage(tester, const ConversationsPage(), device: device);

    expect(find.textContaining('👍 Réaction à'), findsOneWidget);
    expect(find.textContaining('Liked'), findsNothing);
  });
}
