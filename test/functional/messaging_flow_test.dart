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
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    expect(find.byKey(Key('unreadBadge_$threadId')), findsOneWidget);
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

    // Le fil n'a pas encore de message, donc pas de résumé : sans repli sur
    // ses destinataires, il s'ouvrirait sans nom et refuserait ce premier
    // envoi, faute de savoir à qui.
    expect(find.text('Camille'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('composerField')), 'Bonjour !');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();

    expect(device.store.conversations().single.snippet, 'Bonjour !');
  });

  testWidgets('appuyer sur le nom, en haut du fil, ouvre les détails', (
    tester,
  ) async {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(Build.message(threadId: threadId, body: 'Coucou'));

    await pumpApp(tester, device: device);
    await tester.tap(find.byKey(Key('conversationTile_$threadId')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openThreadDetails')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('callParticipant')), findsOneWidget);
    expect(find.byKey(const Key('openContactCard')), findsOneWidget);

    // Et l'on revient au fil, pas à la liste.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('composerField')), findsOneWidget);
  });

  testWidgets('chercher dans le fil, puis revenir sur le message trouvé', (
    tester,
  ) async {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    for (final body in ['Bonjour', 'On se voit au cinéma ?', 'À demain']) {
      device.store.insert(Build.message(threadId: threadId, body: body));
    }

    await pumpApp(tester, device: device);
    await tester.tap(find.byKey(Key('conversationTile_$threadId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openThreadDetails')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('searchThread')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('searchField')), 'cinéma');
    await tester.pumpAndSettle();

    // Un seul message correspond, et la ligne dit qui l'a écrit.
    expect(find.text('Camille'), findsOneWidget);
    await tester.tap(find.textContaining('cinéma').last);
    await tester.pumpAndSettle();

    // On est revenu au fil — et non à l'écran de détails d'où la recherche
    // avait été ouverte.
    expect(find.byKey(const Key('composerField')), findsOneWidget);
    expect(find.text('À demain'), findsOneWidget);

    // Et la liste est toujours dessous : le fil garde une sortie, alors qu'on
    // y est arrivé de deux écrans plus haut.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startChat')), findsOneWidget);
  });

}
