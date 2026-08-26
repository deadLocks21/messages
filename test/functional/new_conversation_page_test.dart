import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/new_conversation/new_conversation.page.dart';
import 'package:messages/ui/pages/new_conversation/widgets/contact_tile.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  TestDevice deviceWithContacts() => TestDevice(
    contacts: [
      Build.contact(displayName: 'Camille Rousseau', addresses: ['0612345678']),
      Build.contact(displayName: 'Julien Marchand', addresses: ['0623456789']),
    ],
  );

  testWidgets('le carnet est proposé d\'emblée', (tester) async {
    await pumpPage(
      tester,
      const NewConversationPage(),
      device: deviceWithContacts(),
    );

    expect(find.text('Camille Rousseau'), findsOneWidget);
    expect(find.text('Julien Marchand'), findsOneWidget);
  });

  testWidgets('le carnet est classé sous des intertitres alphabétiques', (tester) async {
    await pumpPage(
      tester,
      const NewConversationPage(),
      device: TestDevice(
        contacts: [
          Build.contact(displayName: 'Zoé Marin', addresses: ['0611111111']),
          Build.contact(displayName: 'Émile Roux', addresses: ['0622222222']),
          Build.contact(displayName: 'Alice Nguyen', addresses: ['0633333333']),
        ],
      ),
    );

    // « Émile » se range sous E, pas dans une section « É » à part.
    expect(find.byKey(const Key('contactSection_A')), findsOneWidget);
    expect(find.byKey(const Key('contactSection_E')), findsOneWidget);
    expect(find.byKey(const Key('contactSection_Z')), findsOneWidget);

    final names = tester
        .widgetList<ContactTile>(find.byType(ContactTile))
        .map((tile) => tile.contact.displayName)
        .toList();
    expect(names, ['Alice Nguyen', 'Émile Roux', 'Zoé Marin']);
  });

  testWidgets('la saisie filtre les contacts', (tester) async {
    await pumpPage(
      tester,
      const NewConversationPage(),
      device: deviceWithContacts(),
    );
    await tester.enterText(find.byKey(const Key('recipientField')), 'juli');
    await tester.pumpAndSettle();

    expect(find.text('Julien Marchand'), findsOneWidget);
    expect(find.text('Camille Rousseau'), findsNothing);
  });

  testWidgets('un numéro inconnu est proposé tel quel', (tester) async {
    await pumpPage(
      tester,
      const NewConversationPage(),
      device: deviceWithContacts(),
    );
    await tester.enterText(find.byKey(const Key('recipientField')), '0699887766');
    await tester.pumpAndSettle();

    expect(find.text('06 99 88 77 66'), findsOneWidget);
  });

  testWidgets('un transfert annonce le message repris', (tester) async {
    await pumpPage(
      tester,
      const NewConversationPage(forwardedBody: 'Rendez-vous à 20h'),
      device: deviceWithContacts(),
    );

    expect(find.text('Transférer à'), findsOneWidget);
    expect(find.text('Rendez-vous à 20h'), findsOneWidget);
  });
}
