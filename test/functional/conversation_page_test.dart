import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  /// Un fil d'un message entrant, prêt à être ouvert.
  (TestDevice, String) deviceWithThread({SmsAccess access = SmsAccess.full}) {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
      access: access,
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(threadId: threadId, body: 'Tu es dispo ce soir ?'),
    );
    return (device, threadId);
  }

  testWidgets('le fil affiche l\'interlocuteur et ses messages', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    expect(find.text('Camille'), findsOneWidget);
    expect(find.text('Tu es dispo ce soir ?'), findsOneWidget);
  });

  testWidgets('ouvrir le fil marque ses messages comme lus', (tester) async {
    final device = TestDevice();
    final received = device.store.receive(
      from: Address.parse('+33612345678'),
      body: 'Coucou',
    );

    await pumpPage(
      tester,
      ConversationPage(threadId: received.threadId),
      device: device,
    );

    expect(device.store.conversations().single.unreadCount, 0);
  });

  testWidgets('écrire puis envoyer ajoute une bulle sortante', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.enterText(find.byKey(const Key('composerField')), 'Oui, 20h ?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();

    final sent = device.store
        .messagesFor(threadId)
        .firstWhere((m) => m.direction == MessageDirection.outgoing);
    expect(sent.body, 'Oui, 20h ?');
    expect(find.text('Oui, 20h ?'), findsOneWidget);
    expect(find.text('Envoi…'), findsOneWidget);
  });

  testWidgets('le brouillon est conservé en quittant le fil', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.enterText(find.byKey(const Key('composerField')), 'pas fini');
    await tester.pump();
    // Démonter la page déclenche la sauvegarde du brouillon.
    await pumpPage(tester, const SizedBox(), device: device);

    expect(await device.drafts.get(threadId), 'pas fini');
  });

  testWidgets('sans le rôle d\'app par défaut, la rédaction est bloquée', (tester) async {
    final (device, threadId) = deviceWithThread(
      access: const SmsAccess(
        canReadSms: true,
        canSendSms: true,
        canReadContacts: true,
        isDefaultSmsApp: false,
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    expect(find.text('Envoi indisponible'), findsOneWidget);
  });

  testWidgets('un envoi en échec propose de réessayer', (tester) async {
    final device = TestDevice();
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    final failed = Build.message(
      threadId: threadId,
      direction: MessageDirection.outgoing,
      status: MessageStatus.failed,
      body: 'Bon anniversaire !',
    );
    device.store.insert(failed);

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    expect(find.byKey(Key('retry_${failed.id}')), findsOneWidget);
    expect(find.text('Non distribué'), findsOneWidget);
  });

  testWidgets('l\'appui long sur une bulle permet de la supprimer', (tester) async {
    final (device, threadId) = deviceWithThread();
    final message = device.store.messagesFor(threadId).single;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.longPress(find.byKey(Key('bubble_${message.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('messageActionDelete')));
    await tester.pumpAndSettle();

    expect(device.store.messagesFor(threadId), isEmpty);
  });
}
