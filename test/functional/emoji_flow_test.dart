import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/services/emoji_history.repository.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversation/widgets/expression_picker.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

/// L'onglet Emoji : choisir un caractère qu'on ne sait pas taper, et refermer
/// le panneau quand on a fini.
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

  Future<void> openEmoji(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('composerEmoji')));
    await tester.pumpAndSettle();
  }

  /// Le panneau ne fait que 282 dp : sur la surface d'un test, la première
  /// rangée d'emoji dépasse déjà. On l'amène sous le doigt avant de taper.
  Future<void> tapEmoji(WidgetTester tester, String character) async {
    final finder = find.byKey(Key('emoji_$character'));
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  String composerText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('composerField'))).controller!.text;

  testWidgets('le bouton emoji du champ ouvre le panneau sur son onglet', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);

    expect(find.byKey(const Key('expressionPicker')), findsOneWidget);
    expect(find.byKey(const Key('emojiGrid')), findsOneWidget);
    // Les deux onglets, et le second prêt à prendre la main.
    expect(find.byKey(const Key('expressionTab_emoji')), findsOneWidget);
    expect(find.byKey(const Key('expressionTab_gif')), findsOneWidget);
  });

  testWidgets('le même bouton le referme', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    await openEmoji(tester);

    // C'est le geste le plus court pour récupérer le clavier : la main est
    // déjà là.
    expect(find.byKey(const Key('expressionPicker')), findsNothing);
  });

  testWidgets('l\'onglet GIF prend la main sans que l\'en-tête bouge', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    final search = tester.getRect(
      find.byKey(const Key('expressionSearchField')),
    );

    await tester.tap(find.byKey(const Key('expressionTab_gif')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gifGrid')), findsOneWidget);
    expect(find.byKey(const Key('emojiGrid')), findsNothing);
    // Les deux onglets partagent le même en-tête : rien ne doit sauter.
    expect(
      tester.getRect(find.byKey(const Key('expressionSearchField'))),
      search,
    );
  });

  testWidgets('le texte du champ de recherche est centré dans sa pilule', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);

    final pill = tester.getRect(find.byKey(const Key('expressionSearchPill')));
    final hint = tester.getRect(find.text('Rechercher des emoji'));

    // Le padding par défaut d'un champ dense pose le texte contre le haut de
    // sa boîte : sans `textAlignVertical` **et** `contentPadding: zero`, il se
    // lit cinq points au-dessus du centre.
    expect(hint.center.dy, closeTo(pill.center.dy, 1.5));
  });

  testWidgets('les onglets sont un SegmentedButton, et il dit sa sélection', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);

    final button = tester.widget<SegmentedButton<ExpressionTab>>(
      find.byType(SegmentedButton<ExpressionTab>),
    );
    expect(button.selected, {ExpressionTab.emoji});
    // La coche de Material pousserait le libellé hors de son segment, et
    // l'app d'origine n'en montre pas.
    expect(button.showSelectedIcon, isFalse);

    // Deux segments égaux, occupant toute la largeur (relevé : 197,7 dp
    // chacun sur 411).
    final emoji = tester.getRect(find.byKey(const Key('expressionTab_emoji')));
    final gif = tester.getRect(find.byKey(const Key('expressionTab_gif')));
    expect(emoji.center.dy, closeTo(gif.center.dy, 0.5));
  });

  testWidgets('toucher un emoji l\'écrit dans le champ', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    await tapEmoji(tester, '😀');

    expect(composerText(tester), '😀');
    expect(device.emojiHistory.recents(), completion(contains('😀')));
  });

  testWidgets('il s\'insère au curseur, pas au bout', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.enterText(find.byKey(const Key('composerField')), 'salut !');
    // Curseur juste après « salut ».
    final field = tester.widget<TextField>(find.byKey(const Key('composerField')));
    field.controller!.selection = const TextSelection.collapsed(offset: 5);
    await tester.pumpAndSettle();

    await openEmoji(tester);
    await tapEmoji(tester, '😀');

    // On ajoute souvent un emoji au milieu d'une phrase déjà écrite.
    expect(composerText(tester), 'salut😀 !');
  });

  testWidgets('le retour arrière efface un caractère perçu, pas une unité', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.enterText(find.byKey(const Key('composerField')), 'ok👨‍👩‍👧');
    await tester.pumpAndSettle();
    await openEmoji(tester);
    await tester.tap(find.byKey(const Key('emojiBackspace')));
    await tester.pumpAndSettle();

    // Une famille compte huit unités de code : reculer d'une seule laisserait
    // un morceau de famille et une jonction orpheline.
    expect(composerText(tester), 'ok');
  });

  testWidgets('les récents s\'affichent, et le disent quand il n\'y en a pas', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);

    expect(find.byKey(const Key('emojiNoRecents')), findsOneWidget);
    expect(find.text('RÉCENTS'), findsOneWidget);

    await tapEmoji(tester, '😀');

    // Une fois qu'un emoji a servi, la section le montre à la place du mot.
    expect(find.byKey(const Key('emojiNoRecents')), findsNothing);
    expect(find.byKey(const Key('emoji_😀')), findsWidgets);
  });

  testWidgets('la recherche trouve par le nom, accents compris', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    await tester.enterText(
      find.byKey(const Key('expressionSearchField')),
      'coeur',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emojiSearchResults')), findsOneWidget);
    // « coeur » doit trouver « cœur » : sinon la recherche ne sert qu'à ceux
    // qui savent déjà comment l'app l'a orthographié.
    expect(find.byKey(const Key('emoji_❤️')), findsOneWidget);
  });

  testWidgets('la recherche d\'emoji ne fait pas attendre', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    await tester.enterText(
      find.byKey(const Key('expressionSearchField')),
      'licorne',
    );
    // Un seul battement, sans laisser filer les 300 ms des GIF : la table est
    // en mémoire, la faire attendre rendrait la frappe molle.
    await tester.pump();

    expect(find.byKey(const Key('emojiSearchResults')), findsOneWidget);
    expect(find.byKey(const Key('emoji_🦄')), findsOneWidget);
  });

  testWidgets('une recherche sans réponse le dit', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    await tester.enterText(
      find.byKey(const Key('expressionSearchField')),
      'zzzz',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pickerEmpty')), findsOneWidget);
  });

  testWidgets('tirer les onglets ne change pas d\'onglet', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    await tester.drag(
      find.byKey(const Key('expressionTab_emoji')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    // Un glissé qui part d'un onglet finirait par le sélectionner au passage :
    // on se retrouverait sur les GIF pour avoir voulu agrandir les emoji.
    expect(find.byKey(const Key('emojiGrid')), findsOneWidget);
  });

  testWidgets('la barre du bas saute à la famille touchée', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);
    // La quatrième pastille : les animaux.
    await tester.tap(find.byKey(const Key('emojiCategory_3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emoji_🐶')), findsWidgets);
  });

  testWidgets('les récents ne gardent que deux rangées', (tester) async {
    final (device, threadId) = deviceWithThread();
    for (var i = 0; i < EmojiHistoryRepository.maxCount + 5; i++) {
      await device.emojiHistory.remember(String.fromCharCode(0x41 + i));
    }

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await openEmoji(tester);

    // Au-delà, la section pousserait la grille hors de l'écran pour ranger des
    // emoji qu'on n'a mis qu'une fois.
    expect(
      (await device.emojiHistory.recents()).length,
      EmojiHistoryRepository.maxCount,
    );
  });
}
