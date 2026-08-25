import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/new_conversation/new_conversation.page.dart';

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
