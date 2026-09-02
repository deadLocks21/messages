import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/conversation/chat_theme.page.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/theme/chat_theme.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  (TestDevice, String) deviceWithThread() {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(Build.message(threadId: threadId, body: 'Coucou'));
    return (device, threadId);
  }

  /// La couleur d'accent que voit un widget donné : c'est elle qui dit si le
  /// thème du fil s'applique.
  Color accentAt(WidgetTester tester, Finder finder) =>
      tester.element(finder).appColors.accent;

  testWidgets('choisir une couleur la persiste et repeint l\'aperçu', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ChatThemePage(threadId: threadId), device: device);
    final before = accentAt(tester, find.text('Je t\'appelle ce soir'));

    const seed = 0xFF00696E; // sarcelle
    await tester.tap(find.byKey(const Key('chatThemeSeed_$seed')));
    await tester.pumpAndSettle();

    expect((await device.preferences.listAll()).single.themeSeed, seed);
    // La pastille se voit : un `ColoredBox` sans enfant prend la plus petite
    // taille permise, et se peignait sur zéro pixel de large.
    final paint = find.descendant(
      of: find.byKey(const Key('chatThemeSeed_$seed')),
      matching: find.byType(ColoredBox),
    );
    expect(tester.getSize(paint.first).width, greaterThan(0));
    // L'aperçu est rethémé en direct : c'est tout son intérêt.
    expect(accentAt(tester, find.text('Je t\'appelle ce soir')), isNot(before));
  });

  testWidgets('« rétablir » n\'apparaît qu\'une fois le fil thémé', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ChatThemePage(threadId: threadId), device: device);
    expect(find.byKey(const Key('resetChatTheme')), findsNothing);

    await tester.tap(find.byKey(const Key('chatThemeSeed_${0xFF6B4E9E}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resetChatTheme')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resetChatTheme')));
    await tester.pumpAndSettle();

    // Plus rien à persister : le fil est rendu à son état par défaut.
    expect(await device.preferences.listAll(), isEmpty);
    expect(find.byKey(const Key('resetChatTheme')), findsNothing);
  });

  testWidgets('la photo choisie est rangée puis retenue comme fond', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ChatThemePage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('pickWallpaper')));
    await tester.pumpAndSettle();

    expect(device.wallpaper.saved[threadId], isNotNull);
    expect(
      (await device.preferences.listAll()).single.wallpaperPath,
      device.wallpaper.saved[threadId],
    );
  });

  testWidgets('une image illisible se dit, elle ne se pose pas', (
    tester,
  ) async {
    phoneSurface(tester);
    final (device, threadId) = deviceWithThread();
    device.wallpaper.available = false;

    await pumpPage(tester, ChatThemePage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('pickWallpaper')));
    await tester.pumpAndSettle();

    expect(find.text('Cette image n\'a pas pu être lue.'), findsOneWidget);
    expect(await device.preferences.listAll(), isEmpty);
  });

  testWidgets('sans graine, ChatTheme ne touche à rien', (tester) async {
    late Color inside;
    late Color outside;

    await pumpPage(
      tester,
      Builder(
        builder: (context) {
          outside = context.appColors.accent;
          return ChatTheme(
            seed: null,
            child: Builder(
              builder: (context) {
                inside = context.appColors.accent;
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
      device: TestDevice(),
    );

    expect(inside, outside);
  });
}
