import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/ui/pages/conversation/conversation_details.page.dart';
import 'package:messages/ui/pages/conversation/widgets/details_card.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  /// Un fil avec un correspondant au carnet d'adresses.
  (TestDevice, String) deviceWithNamedThread() {
    final device = TestDevice(
      contacts: [
        Build.contact(
          id: 'contact-camille',
          displayName: 'Camille',
          addresses: ['0612345678'],
        ),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(Build.message(threadId: threadId, body: 'Coucou'));
    return (device, threadId);
  }

  /// Un fil dont le numéro n'est dans aucune fiche.
  (TestDevice, String) deviceWithUnknownThread() {
    final device = TestDevice();
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(Build.message(threadId: threadId, body: 'Coucou'));
    return (device, threadId);
  }

  testWidgets('les détails montrent le nom, le numéro et l\'interlocuteur', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithNamedThread();

    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: threadId),
      device: device,
    );

    // Trois fois : le titre de la barre (transparent tant qu'on n'a pas
    // défilé), l'en-tête, et la ligne de la personne.
    expect(find.text('Camille'), findsNWidgets(3));
    // Le numéro formaté, sous le nom et sous la ligne de la personne.
    expect(find.text('06 12 34 56 78'), findsNWidgets(2));
    expect(find.text('1 autre personne'), findsOneWidget);
  });

  testWidgets('un numéro sans fiche ne s\'écrit qu\'une fois sous la pastille', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithUnknownThread();

    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: threadId),
      device: device,
    );

    // Le titre *est* le numéro : la barre, l'en-tête, et le nom de la ligne de
    // la personne — mais aucune ligne qui le répète sous l'un des deux.
    expect(find.text('06 12 34 56 78'), findsNWidgets(3));
    expect(find.byKey(const Key('copyAddress')), findsNothing);
  });

  testWidgets('un contact connu propose sa fiche, un inconnu sa création', (
    tester,
  ) async {
    phoneSurface(tester);
    final (named, namedThread) = deviceWithNamedThread();
    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: namedThread),
      device: named,
    );
    expect(find.byKey(const Key('openContactCard')), findsOneWidget);
    expect(find.byKey(const Key('addContact')), findsNothing);

    await tester.tap(find.byKey(const Key('openContactCard')));
    await tester.pumpAndSettle();
    expect(named.contactCard.opened, ['contact-camille']);

    final (unknown, unknownThread) = deviceWithUnknownThread();
    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: unknownThread),
      device: unknown,
    );
    expect(find.byKey(const Key('addContact')), findsOneWidget);

    await tester.tap(find.byKey(const Key('addContact')));
    await tester.pumpAndSettle();
    expect(unknown.contactCard.created, ['+33612345678']);
  });

  testWidgets('sans app de contacts, l\'appui le dit plutôt que de rien faire', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithNamedThread();
    device.contactCard.available = false;

    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: threadId),
      device: device,
    );
    await tester.tap(find.byKey(const Key('openContactCard')));
    await tester.pumpAndSettle();

    expect(find.text('Aucune application de contacts disponible.'), findsOneWidget);
  });

  testWidgets('appuyer sur le numéro le copie', (tester) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithNamedThread();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: threadId),
      device: device,
    );
    await tester.tap(find.byKey(const Key('copyAddress')));
    await tester.pumpAndSettle();

    // C'est l'adresse brute qui est copiée, pas sa mise en forme : c'est elle
    // qu'on recolle dans un composeur d'appel.
    expect(copied, '+33612345678');
    expect(find.text('Numéro copié'), findsOneWidget);
  });

  testWidgets('les réglages du fil basculent depuis les détails', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithNamedThread();

    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: threadId),
      device: device,
    );

    expect(find.text('Épingler'), findsOneWidget);
    await tester.tap(find.byKey(const Key('togglePinned')));
    await tester.pumpAndSettle();
    expect(find.text('Ne plus épingler'), findsOneWidget);

    expect(find.text('Mettre en veille'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggleSnooze')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('snooze_8')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSnooze')));
    await tester.pumpAndSettle();
    expect(find.text('Réactiver les notifications'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggleArchived')));
    await tester.pumpAndSettle();
    expect(find.text('Désarchiver'), findsOneWidget);

    final preference = (await device.preferences.listAll()).single;
    expect(preference.threadId, threadId);
    // Huit heures : une veille à échéance, pas une sourdine sans fin.
    expect(preference.muted, isFalse);
    expect(preference.snoozedUntil, isNotNull);
    expect(preference.archived, isTrue);
    // Archiver dépingle : les deux états s'excluent, et l'écran de détails
    // passe par le même cas d'usage que le menu « ⋮ ».
    expect(preference.pinned, isFalse);
    expect(find.text('Épingler'), findsOneWidget);
  });

  testWidgets('un fil de groupe liste ses membres et cache les boutons ronds', (
    tester,
  ) async {
    phoneSurface(tester);
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
        Build.contact(displayName: 'Bruno', addresses: ['0698765432']),
      ],
    );
    final threadId = device.store.threadIdFor([
      Address.parse('+33612345678'),
      Address.parse('+33698765432'),
    ]);
    device.store.insert(Build.message(threadId: threadId, body: 'À ce soir'));

    await pumpPage(
      tester,
      ConversationDetailsPage(threadId: threadId),
      device: device,
    );

    expect(find.text('2 autres personnes'), findsOneWidget);
    expect(find.byType(DetailsMemberRow), findsNWidgets(2));
    // À plusieurs, il n'y a pas *un* numéro à appeler.
    expect(find.byKey(const Key('callParticipant')), findsNothing);
  });
}
