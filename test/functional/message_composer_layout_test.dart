import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';
import 'package:messages/ui/theme/app_theme_data.dart';

/// Mise en page du champ de rédaction.
///
/// Ces vérifications portent sur des **positions mesurées**, pas sur la
/// présence des widgets : un décalage de quelques pixels ne casse aucun test
/// classique, mais se voit immédiatement à l'écran.
void main() {
  Future<TextEditingController> pumpComposer(WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeData.buildLightTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MessageComposer(
              controller: controller,
              onSend: (_) {},
              enabled: true,
              onAttach: () {},
              onVoice: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Rect pill(WidgetTester tester) => tester.getRect(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.minHeight == MessageComposer.pillHeight,
    ),
  );

  testWidgets('sur une ligne, le « + » est centré dans la pilule', (
    tester,
  ) async {
    await pumpComposer(tester);

    final plus = tester.getRect(find.byKey(const Key('composerAttach')));
    expect(plus.center.dy, closeTo(pill(tester).center.dy, 0.5));
  });

  testWidgets('le « + » reste en bas quand le champ grandit', (tester) async {
    // Avec le champ sur plusieurs lignes, le bouton doit longer la dernière
    // ligne — pas flotter au milieu d'une pilule devenue haute.
    final controller = await pumpComposer(tester);
    controller.text = List.filled(12, 'une phrase assez longue').join(' ');
    await tester.pumpAndSettle();

    final box = pill(tester);
    final plus = tester.getRect(find.byKey(const Key('composerAttach')));

    expect(box.height, greaterThan(MessageComposer.pillHeight * 2));
    expect(plus.bottom, closeTo(box.bottom, 0.5));
    expect(plus.center.dy, greaterThan(box.center.dy));
  });

  testWidgets('le disque fait la même hauteur que la pilule, vocal ou envoi', (
    tester,
  ) async {
    // Les deux boutons se succèdent au même endroit : ils doivent se mesurer
    // sur la pilule de la même façon, sinon la ligne saute à la première
    // lettre tapée.
    final controller = await pumpComposer(tester);

    final voice = tester.getRect(find.byKey(const Key('recordVoice')));
    expect(voice.height, MessageComposer.pillHeight);
    expect(voice.center.dy, closeTo(pill(tester).center.dy, 0.5));

    controller.text = 'Coucou';
    await tester.pumpAndSettle();

    final send = tester.getRect(find.byKey(const Key('sendMessage')));
    expect(send, voice);
  });

  testWidgets('le disque est le vocal tant qu\'il n\'y a rien à envoyer', (
    tester,
  ) async {
    // C'est le geste qui rend le vocal atteignable : il occupe la place d'un
    // bouton d'envoi qui, le champ vide, n'aurait rien à envoyer.
    final controller = await pumpComposer(tester);

    expect(find.byKey(const Key('recordVoice')), findsOneWidget);
    expect(find.byKey(const Key('sendMessage')), findsNothing);

    controller.text = 'Coucou';
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sendMessage')), findsOneWidget);
    expect(find.byKey(const Key('recordVoice')), findsNothing);

    // Un champ vidé rend la place au vocal.
    controller.text = '';
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recordVoice')), findsOneWidget);
  });
}
