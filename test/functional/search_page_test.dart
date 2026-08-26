import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/ui/pages/search/search.page.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  TestDevice deviceWithHistory() {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(threadId: threadId, body: 'Rendez-vous au cinéma à 20h'),
    );
    return device;
  }

  testWidgets('une requête trop courte n\'affiche rien', (tester) async {
    await pumpPage(tester, const SearchPage(), device: deviceWithHistory());
    await tester.enterText(find.byKey(const Key('searchField')), 'c');
    await tester.pumpAndSettle();

    expect(find.text('Saisissez au moins 2 caractères.'), findsOneWidget);
  });

  testWidgets('la recherche remonte le fil puis le message', (tester) async {
    await pumpPage(tester, const SearchPage(), device: deviceWithHistory());
    await tester.enterText(find.byKey(const Key('searchField')), 'cinéma');
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.textContaining('cinéma', findRichText: true), findsWidgets);
  });

  testWidgets('un fil se trouve par le nom du contact', (tester) async {
    await pumpPage(tester, const SearchPage(), device: deviceWithHistory());
    await tester.enterText(find.byKey(const Key('searchField')), 'cami');
    await tester.pumpAndSettle();

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Camille'), findsWidgets);
  });

  testWidgets('le filtre « Non lues » masque les fils déjà lus', (tester) async {
    final device = TestDevice();
    final lu = device.store.threadIdFor([Build.address('0611111111')]);
    device.store.insert(
      Build.message(threadId: lu, address: '0611111111', body: 'Déjà lu'),
    );
    device.store.receive(
      from: Address.parse('0622222222'),
      body: 'Pas encore lu',
    );

    await pumpPage(tester, const SearchPage(), device: device);
    await tester.tap(find.byKey(const Key('filterUnread')));
    await tester.pumpAndSettle();

    expect(find.text('Pas encore lu'), findsOneWidget);
    expect(find.text('Déjà lu'), findsNothing);
  });

  testWidgets('taper une requête retire le filtre actif', (tester) async {
    await pumpPage(tester, const SearchPage(), device: deviceWithHistory());
    await tester.tap(find.byKey(const Key('filterUnread')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activeFilterPill')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('searchField')), 'cinéma');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activeFilterPill')), findsNothing);
    expect(find.textContaining('cinéma', findRichText: true), findsWidgets);
  });

  testWidgets('sans correspondance, l\'écran le dit', (tester) async {
    await pumpPage(tester, const SearchPage(), device: deviceWithHistory());
    await tester.enterText(find.byKey(const Key('searchField')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucun résultat'), findsOneWidget);
  });
}
