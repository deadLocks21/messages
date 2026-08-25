import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/ui/pages/welcome/welcome.page.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('l\'accueil demande d\'abord les autorisations', (tester) async {
    final device = TestDevice(access: SmsAccess.none);

    await pumpPage(tester, const WelcomePage(), device: device);

    expect(find.text('Bienvenue dans Messages'), findsOneWidget);
    expect(find.byKey(const Key('grantPermissions')), findsOneWidget);
    expect(find.byKey(const Key('grantDefaultApp')), findsNothing);
  });

  testWidgets('une fois les permissions accordées, il demande le rôle', (tester) async {
    final device = TestDevice(
      access: const SmsAccess(
        canReadSms: true,
        canSendSms: true,
        canReadContacts: true,
        isDefaultSmsApp: false,
      ),
    );

    await pumpPage(tester, const WelcomePage(), device: device);

    expect(find.byKey(const Key('grantDefaultApp')), findsOneWidget);
  });

  testWidgets('accorder les permissions fait avancer l\'accueil', (tester) async {
    final device = TestDevice(access: SmsAccess.none);

    await pumpPage(tester, const WelcomePage(), device: device);
    await tester.tap(find.byKey(const Key('grantPermissions')));
    await tester.pumpAndSettle();

    expect((await device.permissions.check()).canReadSms, isTrue);
    expect(find.byKey(const Key('grantDefaultApp')), findsOneWidget);
  });
}
