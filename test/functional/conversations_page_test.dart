import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/ui/pages/conversations/conversations.page.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('la liste affiche les fils, nommés par le carnet', (tester) async {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(threadId: threadId, body: 'On se voit ce soir ?'),
    );

    await pumpPage(tester, const ConversationsPage(), device: device);

    expect(find.text('Camille'), findsOneWidget);
    expect(find.text('On se voit ce soir ?'), findsOneWidget);
    expect(find.byKey(Key('conversationTile_$threadId')), findsOneWidget);
  });

  testWidgets('un fil non lu porte une pastille de compteur', (tester) async {
    final device = TestDevice();
    device.store.receive(from: Address.parse('+33612345678'), body: 'Coucou');
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);

    await pumpPage(tester, const ConversationsPage(), device: device);

    final badge = find.byKey(Key('unreadBadge_$threadId'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);
  });

  testWidgets('un fil lu n\'a pas de pastille', (tester) async {
    final device = TestDevice();
    final threadId = device.store.threadIdFor([Build.address('0611111111')]);
    device.store.insert(
      Build.message(threadId: threadId, address: '0611111111', body: 'Déjà lu'),
    );

    await pumpPage(tester, const ConversationsPage(), device: device);

    expect(find.byKey(Key('unreadBadge_$threadId')), findsNothing);
  });

  testWidgets('sans conversation, l\'écran invite à en démarrer une', (tester) async {
    await pumpPage(tester, const ConversationsPage(), device: TestDevice());

    expect(find.text('Aucune conversation'), findsOneWidget);
    expect(find.byKey(const Key('startChat')), findsOneWidget);
  });

  testWidgets('sourdine et épinglage se lisent près de l\'horodatage', (tester) async {
    final device = TestDevice();
    final threadId = device.store.threadIdFor([Build.address('0611111111')]);
    device.store.insert(
      Build.message(threadId: threadId, address: '0611111111', body: 'Coucou'),
    );
    await device.preferences.save(
      ConversationPreference(threadId: threadId, pinned: true, muted: true),
    );

    await pumpPage(tester, const ConversationsPage(), device: device);

    // Les deux marques vivent sur la ligne de l'horodatage — pas dans
    // l'aperçu, qui garde toute sa largeur.
    final meta = find.byKey(Key('threadMeta_$threadId'));
    expect(meta, findsOneWidget);
    expect(
      find.descendant(of: meta, matching: find.byIcon(Icons.push_pin)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: meta,
        matching: find.byIcon(Icons.notifications_off_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('la pastille de compte ouvre la feuille du compte', (tester) async {
    await pumpPage(tester, const ConversationsPage(), device: TestDevice());

    await tester.tap(find.byKey(const Key('accountMenu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('accountArchived')), findsOneWidget);
    expect(find.byKey(const Key('accountSettings')), findsOneWidget);
  });

  testWidgets('un bandeau réclame le rôle d\'app SMS par défaut', (tester) async {
    final device = TestDevice(
      access: SmsAccess.full.copyWith(isDefaultSmsApp: false),
    );

    await pumpPage(tester, const ConversationsPage(), device: device);

    expect(find.byKey(const Key('defaultAppBanner')), findsOneWidget);
  });

  testWidgets('l\'appui long ouvre le mode sélection et permet d\'archiver', (tester) async {
    final device = TestDevice();
    final threadId = device.store.threadIdFor([Build.address('0611111111')]);
    device.store.insert(
      Build.message(threadId: threadId, address: '0611111111', body: 'À ranger'),
    );

    await pumpPage(tester, const ConversationsPage(), device: device);
    await tester.longPress(find.byKey(Key('conversationTile_$threadId')));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('selectionArchive')));
    await tester.pumpAndSettle();

    expect((await device.preferences.listAll()).single.archived, isTrue);
    expect(find.text('À ranger'), findsNothing);
  });
}
