import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_sheet.widget.dart';

import '../builders/builders.dart';
import '../helpers/test_app.dart';

void main() {
  /// Un fil ouvert sur Camille, avec un message déjà là.
  (TestDevice, String) deviceWithThread() {
    final device = TestDevice(
      contacts: [
        Build.contact(displayName: 'Camille', addresses: ['0612345678']),
      ],
    );
    final threadId = device.store.threadIdFor([Build.address('+33612345678')]);
    device.store.insert(
      Build.message(threadId: threadId, body: 'Tu me l\'envoies ?'),
    );
    return (device, threadId);
  }

  /// Ouvre le panneau des pièces jointes et choisit [label].
  Future<void> attach(WidgetTester tester, String source) async {
    await tester.tap(find.byKey(const Key('composerAttach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('attachFrom_$source')));
    await tester.pumpAndSettle();
  }

  testWidgets('le bouton « + » ouvre le panneau des sources', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('composerAttach')));
    await tester.pumpAndSettle();

    expect(find.byType(AttachmentSheet), findsOneWidget);
    expect(find.text('Galerie'), findsOneWidget);
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.text('Fichiers'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
  });

  testWidgets('choisir une photo la pose sur le plateau', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await attach(tester, 'gallery');

    expect(find.byKey(const Key('attachmentTray')), findsOneWidget);
    expect(device.attachments.requested, [AttachmentSource.gallery]);
  });

  testWidgets('refermer le sélecteur sans rien choisir ne pose rien', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.attachments.cancelNext = true;

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await attach(tester, 'camera');

    expect(find.byKey(const Key('attachmentTray')), findsNothing);
  });

  testWidgets('une photo seule suffit à envoyer, sans une ligne de texte', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await attach(tester, 'gallery');
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();

    final sent = device.store
        .messagesFor(threadId)
        .where((m) => m.isOutgoing)
        .single;
    expect(sent.body, '');
    expect(sent.attachments.single.kind, AttachmentKind.image);
    // Le plateau s'est vidé avec l'envoi : les vignettes ne doivent pas rester
    // au-dessus du champ comme si rien n'était parti.
    expect(find.byKey(const Key('attachmentTray')), findsNothing);
  });

  testWidgets('une pièce jointe part avec sa légende', (tester) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await attach(tester, 'files');
    await tester.enterText(find.byKey(const Key('composerField')), 'Le billet');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();

    final sent = device.store
        .messagesFor(threadId)
        .where((m) => m.isOutgoing)
        .single;
    expect(sent.body, 'Le billet');
    expect(sent.attachments.single.fileName, 'Billet.pdf');
  });

  testWidgets('une vignette se retire du plateau avant l\'envoi', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await attach(tester, 'gallery');

    final removeButton = find.byWidgetPredicate(
      (w) => w is InkWell && w.key.toString().contains('removeAttachment_'),
    );
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attachmentTray')), findsNothing);
    // Plus rien à envoyer : le bouton doit s'être rééteint.
    await tester.tap(find.byKey(const Key('sendMessage')));
    await tester.pumpAndSettle();
    expect(device.store.messagesFor(threadId).where((m) => m.isOutgoing),
        isEmpty);
  });

  testWidgets('la bulle d\'un MMS reçu montre sa pièce jointe', (tester) async {
    final (device, threadId) = deviceWithThread();
    final attachment = Build.attachment(
      id: 'part-42',
      mimeType: 'application/pdf',
      fileName: 'Contrat.pdf',
      byteSize: 4096,
    );
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [attachment],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    expect(find.byKey(const Key('attachment_part-42')), findsOneWidget);
    expect(find.text('Contrat.pdf'), findsOneWidget);
    expect(find.text('4 Ko'), findsOneWidget);
  });

  testWidgets('une bulle se serre sur son texte, elle ne s\'étire pas', (
    tester,
  ) async {
    // Régression : en accueillant les pièces jointes, la bulle est passée d'un
    // `Text` à une `Column`. Avec `CrossAxisAlignment.stretch`, *toutes* les
    // bulles se mettaient à occuper la largeur maximale — « Ok » aussi large
    // qu'un paragraphe.
    final (device, threadId) = deviceWithThread();
    device.store.insert(
      Build.message(id: 'court', threadId: threadId, body: 'Ok'),
    );
    device.store.insert(
      Build.message(
        id: 'long',
        threadId: threadId,
        body: 'Une phrase nettement plus longue que le message précédent, '
            'de quoi occuper toute la largeur disponible.',
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    final court = tester.getSize(find.byKey(const Key('bubble_court'))).width;
    final long = tester.getSize(find.byKey(const Key('bubble_long'))).width;
    expect(court, lessThan(long));
    expect(court, lessThan(tester.view.physicalSize.width / 4));
  });

  testWidgets('la liste des fils annonce « Photo » pour un MMS sans légende', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        sentAt: DateTime(2026, 8, 26, 12),
        attachments: [Build.attachment(mimeType: 'image/png')],
      ),
    );

    await pumpApp(tester, device: device);

    expect(find.text('Photo'), findsOneWidget);
  });
}
