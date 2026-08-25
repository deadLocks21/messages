import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
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

  testWidgets('un fil non lu alimente la puce « Non lus »', (tester) async {
    final device = TestDevice();
    device.store.receive(from: Address.parse('+33612345678'), body: 'Coucou');

    await pumpPage(tester, const ConversationsPage(), device: device);

    expect(find.text('Non lus · 1'), findsOneWidget);
  });

  testWidgets('le filtre « Non lus » masque les fils déjà lus', (tester) async {
    final device = TestDevice();
    final lu = device.store.threadIdFor([Build.address('0611111111')]);
    device.store.insert(
      Build.message(threadId: lu, address: '0611111111', body: 'Déjà lu'),
    );
    device.store.receive(from: Address.parse('0622222222'), body: 'Pas encore lu');

    await pumpPage(tester, const ConversationsPage(), device: device);
    await tester.tap(find.byKey(const Key('filterUnread')));
    await tester.pumpAndSettle();

    expect(find.text('Pas encore lu'), findsOneWidget);
    expect(find.text('Déjà lu'), findsNothing);
  });

  testWidgets('sans conversation, l\'écran invite à en démarrer une', (tester) async {
    await pumpPage(tester, const ConversationsPage(), device: TestDevice());

    expect(find.text('Aucune conversation'), findsOneWidget);
    expect(find.byKey(const Key('startChat')), findsOneWidget);
  });

  testWidgets('un bandeau réclame le rôle d\'app SMS par défaut', (tester) async {
    final device = TestDevice(
      access: const SmsAccess(
        canReadSms: true,
        canSendSms: true,
        canReadContacts: true,
        isDefaultSmsApp: false,
      ),
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
