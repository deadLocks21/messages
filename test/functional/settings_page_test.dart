import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/ui/pages/settings/settings.page.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('les paramètres exposent le thème et l\'état SMS', (tester) async {
    await pumpPage(tester, const SettingsPage(), device: TestDevice());

    expect(find.text('Clair'), findsOneWidget);
    expect(find.text('Sombre'), findsOneWidget);
    expect(find.text('Messages est votre application SMS.'), findsOneWidget);
  });

  testWidgets('choisir un thème le persiste', (tester) async {
    final device = TestDevice();

    await pumpPage(tester, const SettingsPage(), device: device);
    await tester.tap(find.byKey(const Key('themeMode_dark')));
    await tester.pumpAndSettle();

    expect(await device.theme.get(), AppThemeMode.dark);
  });

  testWidgets('notifications coupées : un bouton propose de les activer', (tester) async {
    final device = TestDevice(
      access: SmsAccess.full.copyWith(canNotify: false),
    );

    await pumpPage(tester, const SettingsPage(), device: device);

    expect(
      find.text('Désactivées : aucun message reçu ne sera signalé.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('enableNotifications')));
    await tester.pumpAndSettle();

    expect((await device.permissions.check()).canNotify, isTrue);
    expect(device.permissions.openSettingsCount, 0);
  });

  testWidgets('un refus définitif renvoie vers les réglages système', (tester) async {
    // La demande ne rend plus rien : c'est le signe d'un refus définitif.
    final device = TestDevice(
      access: SmsAccess.full.copyWith(canNotify: false),
      grantedOnRequest: SmsAccess.full.copyWith(canNotify: false),
    );

    await pumpPage(tester, const SettingsPage(), device: device);
    await tester.tap(find.byKey(const Key('enableNotifications')));
    await tester.pumpAndSettle();

    expect(device.permissions.openSettingsCount, 1);
  });

  testWidgets('sans le rôle par défaut, un bouton le propose', (tester) async {
    final device = TestDevice(
      access: SmsAccess.full.copyWith(isDefaultSmsApp: false),
    );

    await pumpPage(tester, const SettingsPage(), device: device);

    expect(find.text('Définir'), findsOneWidget);

    await tester.tap(find.text('Définir'));
    await tester.pumpAndSettle();

    expect((await device.permissions.check()).isDefaultSmsApp, isTrue);
  });
}
