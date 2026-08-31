import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_tray.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

/// Choisir un GIF et l'envoyer, comme dans l'app d'origine.
void main() {
  (TestDevice, String) deviceWithThread() {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(Build.message(threadId: threadId, body: 'Alors ?'));
    return (device, threadId);
  }

  /// Ouvre « + » puis la case GIF.
  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composerAttach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attachFrom_gif')));
    await tester.pumpAndSettle();
  }

  testWidgets('le panneau des sources propose le GIF', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('composerAttach')));
    await tester.pumpAndSettle();

    // Les trois premières cases de l'app d'origine, dans le même ordre.
    expect(find.text('Galerie'), findsOneWidget);
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.text('GIF'), findsOneWidget);
  });

  testWidgets('le sélecteur se déploie sous le champ, pas par-dessus', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);

    expect(find.byKey(const Key('expressionPicker')), findsOneWidget);
    expect(find.byKey(const Key('expressionSearchField')), findsOneWidget);
    // Le champ de rédaction reste visible et au-dessus : dans l'app d'origine
    // le panneau pousse le fil, il ne masque jamais ce qu'on vient d'écrire.
    final composer = tester.getRect(find.byKey(const Key('composerField')));
    final picker = tester.getRect(find.byKey(const Key('expressionPicker')));
    expect(composer.bottom, lessThanOrEqualTo(picker.top));
  });

  testWidgets('la grille pose deux colonnes en quinconce', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);

    final tiles = find.byWidgetPredicate(
      (w) => w is InkWell && (w.key as ValueKey<String>?)?.value.startsWith('gif_') == true,
    );
    expect(tiles, findsWidgets);

    final lefts = tester
        .widgetList<InkWell>(tiles)
        .map((w) => tester.getRect(find.byKey(w.key!)).left)
        .toSet();
    // Deux abscisses, pas plus : deux colonnes.
    expect(lefts.length, 2);

    // Et des hauteurs différentes d'une vignette à l'autre — sans quoi ce
    // serait un damier, et les GIF panoramiques seraient recadrés.
    final heights = tester
        .widgetList<InkWell>(tiles)
        .map((w) => tester.getRect(find.byKey(w.key!)).height.round())
        .toSet();
    expect(heights.length, greaterThan(1));
  });

  testWidgets('toucher un GIF le pose sur le plateau et referme le panneau', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.tap(find.byKey(const Key('expressionPicker')));
    final tile = find
        .byWidgetPredicate(
          (w) => w is InkWell &&
              (w.key as ValueKey<String>?)?.value.startsWith('gif_') == true,
        )
        .first;
    await tester.tap(tile, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Joint, pas envoyé : c'est le champ de rédaction qui garde le dernier
    // mot, et c'est ce qui laisse ajouter une légende.
    expect(find.byType(AttachmentTrayBar), findsOneWidget);
    expect(find.byKey(const Key('attachmentTray')), findsOneWidget);
    expect(find.byKey(const Key('expressionPicker')), findsNothing);
    expect(device.store.messagesFor(threadId).where((m) => m.isOutgoing), isEmpty);
    expect(device.downloads.downloaded, hasLength(1));
  });

  testWidgets('le GIF part en MMS avec la légende ajoutée', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is InkWell &&
                (w.key as ValueKey<String>?)?.value.startsWith('gif_') == true,
          )
          .first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('composerField')), 'Tiens 😄');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();

    final sent = device.store.messagesFor(threadId).firstWhere((m) => m.isOutgoing);
    expect(sent.body, 'Tiens 😄');
    expect(sent.attachments.single.mimeType, 'image/gif');
  });

  testWidgets('seules les vignettes proches de l\'écran s\'animent', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);

    final tiles = find.byWidgetPredicate(
      (w) =>
          w is InkWell &&
          (w.key as ValueKey<String>?)?.value.startsWith('gif_') == true,
    );
    // Le catalogue simulé n'a rien à décoder : il peint son libellé, et ce
    // libellé n'est peint que là où une vraie vignette se serait animée.
    final painted = find.byWidgetPredicate(
      (w) => w is Text && (w.data?.endsWith(' GIF') ?? false),
    );

    // Cent GIF qui décodent une image toutes les cinquante millisecondes
    // occuperaient le processeur à ne rien montrer : la grille en tient
    // beaucoup plus qu'elle n'en anime.
    expect(
      tester.widgetList(painted).length,
      lessThan(tester.widgetList(tiles).length),
    );
    expect(tester.widgetList(painted), isNotEmpty);
  });

  testWidgets('tirer l\'en-tête vers le haut déplie le panneau', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    final collapsed = tester.getSize(find.byKey(const Key('expressionPicker'))).height;

    // Un glissé fluide, en petits pas : c'est la distance parcourue qui
    // décide, aucun de ces pas n'atteignant le seuil à lui seul.
    await tester.drag(find.byKey(const Key('expressionSearchField')), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('expressionPicker'))).height,
      greaterThan(collapsed),
    );
  });

  testWidgets('replié, un dernier glissé vers le bas le referme', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.drag(find.byKey(const Key('expressionSearchField')), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expressionPicker')), findsNothing);
  });

  testWidgets('la recherche de GIF attend que la frappe s\'arrête', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.enterText(
      find.byKey(const Key('expressionSearchField')),
      'c',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const Key('expressionSearchField')),
      'chat',
    );
    // Un `Timer` ne programme pas d'image : `pumpAndSettle` seul rendrait la
    // main sans avoir avancé jusqu'à l'échéance.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // « chat » lancerait quatre requêtes dont trois seraient jetées, et la
    // grille clignoterait à chaque lettre.
    expect(device.gifs.searched, ['chat']);
  });

  testWidgets('la grille suit le terme cherché', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.enterText(
      find.byKey(const Key('expressionSearchField')),
      'bravo',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(device.gifs.searched, ['bravo']);
    expect(find.byKey(const Key('gifGrid')), findsOneWidget);
  });

  testWidgets('un catalogue muet le dit au lieu de rester vide', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.gifs.empty = true;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);

    expect(find.byKey(const Key('pickerEmpty')), findsOneWidget);
  });

  testWidgets('un GIF qui ne descend pas se dit, il ne se tait pas', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.downloads.failNext = true;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is InkWell &&
                (w.key as ValueKey<String>?)?.value.startsWith('gif_') == true,
          )
          .first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ce GIF n\'a pas pu être téléchargé.'), findsOneWidget);
    expect(find.byKey(const Key('attachmentTray')), findsNothing);
  });

  testWidgets('un opérateur avare fait choisir une déclinaison plus légère', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.carrier.value = const MmsLimits(maxTotalBytes: 72 * 1024);

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openPicker(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is InkWell &&
                (w.key as ValueKey<String>?)?.value.startsWith('gif_') == true,
          )
          .first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Ce n'est pas le plein format qui est descendu : la taille du GIF suit le
    // budget lu de l'opérateur, comme la longueur d'un vocal.
    expect(device.downloads.downloaded.single, endsWith('/44'));
  });
}
