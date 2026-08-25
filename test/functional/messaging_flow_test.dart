import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/sms_access.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

/// Parcours de bout en bout, routeur compris : c'est le seul test qui monte
/// l'application entière.
void main() {
  testWidgets('sans accès aux SMS, l\'app s\'ouvre sur l\'accueil', (tester) async {
    await pumpApp(tester, device: TestDevice(access: SmsAccess.none));

    expect(find.text('Bienvenue dans Messages'), findsOneWidget);
  });

  testWidgets('ouvrir un fil depuis la liste, puis répondre', (tester) async {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(threadId: threadId, body: 'Tu es dispo ce soir ?'),
    );

    await pumpApp(tester, device: device);
    await tester.tap(find.byKey(Key('conversationTile_$threadId')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composerField')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('composerField')), 'Oui !');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();

    expect(
      device.store
          .messagesFor(threadId)
          .where((m) => m.direction == MessageDirection.outgoing)
          .single
          .body,
      'Oui !',
    );
  });

  testWidgets('un SMS reçu apparaît sans rafraîchissement manuel', (tester) async {
    final device = TestDevice();

    await pumpApp(tester, device: device);
    expect(find.text('Aucune conversation'), findsOneWidget);

    // Ce que fait le récepteur SMS_DELIVER côté Android.
    device.store.receive(
      from: Address.parse('+33612345678'),
      body: 'Je suis en bas',
    );
    await tester.pumpAndSettle();

    expect(find.text('Je suis en bas'), findsOneWidget);
    expect(find.text('Non lus · 1'), findsOneWidget);
  });

  testWidgets('démarrer une conversation depuis le sélecteur de contacts', (tester) async {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );

    await pumpApp(tester, device: device);
    await tester.tap(find.byKey(const Key('startChat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camille'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('composerField')), findsOneWidget);
    expect(find.text('Aucun message pour l\'instant.\nÉcrivez le premier.'), findsOneWidget);
  });
}
