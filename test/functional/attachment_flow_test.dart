import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/sample_image.dart';
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
    // Plus rien à envoyer : le disque redevient celui du vocal, et il n'y a
    // plus de bouton d'envoi à toucher.
    expect(find.byKey(const Key('sendMessage')), findsNothing);
    expect(find.byKey(const Key('recordVoice')), findsOneWidget);
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

  /// Un fil où Camille a envoyé une photo, octets compris — sans eux, il n'y
  /// aurait rien à agrandir.
  (TestDevice, String) deviceWithReceivedPhoto() {
    final (device, threadId) = deviceWithThread();
    device.store.putAttachmentBytes(
      'part-7',
      SampleImage.solid(width: 8, height: 6, argb: 0xFF5BB874),
    );
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-7',
            mimeType: 'image/png',
            width: 800,
            height: 600,
          ),
        ],
      ),
    );
    return (device, threadId);
  }

  testWidgets('toucher la photo d\'un MMS l\'ouvre en grand', (tester) async {
    final (device, threadId) = deviceWithReceivedPhoto();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attachmentViewer')), findsOneWidget);
    expect(find.byKey(const Key('viewerImage_part-7')), findsOneWidget);

    await tester.tap(find.byKey(const Key('closeAttachmentViewer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attachmentViewer')), findsNothing);
    expect(find.byKey(const Key('attachment_part-7')), findsOneWidget);
  });

  testWidgets('l\'appui long sur une photo reste celui de la bulle', (
    tester,
  ) async {
    // L'ouverture en grand a posé un `onTap` *sous* le `onLongPress` de la
    // bulle : les deux gestes doivent continuer à cohabiter, sinon les actions
    // du message deviennent inatteignables sur un MMS.
    final (device, threadId) = deviceWithReceivedPhoto();

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.longPress(find.byKey(const Key('attachment_part-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attachmentViewer')), findsNothing);
    expect(find.byKey(const Key('messageActionCopy')), findsOneWidget);
  });

  testWidgets('un PDF ne s\'ouvre pas en grand : il n\'y a rien à voir', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-8',
            mimeType: 'application/pdf',
            fileName: 'Contrat.pdf',
          ),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-8')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attachmentViewer')), findsNothing);
  });

  testWidgets('un PDF s\'ouvre dans l\'application du système', (tester) async {
    final (device, threadId) = deviceWithThread();
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-pdf',
            mimeType: 'application/pdf',
            fileName: 'Contrat.pdf',
          ),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-pdf')));
    await tester.pumpAndSettle();

    // L'app ne sait pas afficher un PDF, et n'a pas à apprendre : elle le
    // passe à qui sait le faire.
    expect(device.opener.opened, ['part-pdf']);
  });

  testWidgets('une vidéo part au lecteur du système', (tester) async {
    final (device, threadId) = deviceWithThread();
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-video',
            mimeType: 'video/mp4',
            width: 800,
            height: 600,
          ),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-video')));
    await tester.pumpAndSettle();

    expect(device.opener.opened, ['part-video']);
    // Surtout pas le visionneur d'images : il n'aurait rien à décoder.
    expect(find.byKey(const Key('attachmentViewer')), findsNothing);
  });

  testWidgets('sans application pour l\'ouvrir, la bulle le dit', (
    tester,
  ) async {
    // Un appui qui ne produit rien du tout laisserait croire à une bulle
    // cassée.
    final (device, threadId) = deviceWithThread();
    device.opener.canOpen = false;
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-exotique',
            mimeType: 'application/x-inconnu',
            fileName: 'truc.xyz',
          ),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-exotique')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('noAppForAttachment')), findsOneWidget);
    expect(
      find.text('Aucune application ne peut ouvrir ce fichier'),
      findsOneWidget,
    );
    // Et une porte de sortie : le fichier peut au moins être gardé.
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  testWidgets('faute de pouvoir l\'ouvrir, on peut l\'enregistrer', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.opener.canOpen = false;
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-exotique',
            mimeType: 'application/x-inconnu',
            fileName: 'truc.xyz',
          ),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-exotique')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(device.opener.saved, ['part-exotique']);
    expect(find.byKey(const Key('attachmentSaved')), findsOneWidget);
  });

  testWidgets('renoncer à l\'enregistrement ne dit rien', (tester) async {
    // L'utilisateur qui ferme le sélecteur de destination sait ce qu'il vient
    // de faire : le lui confirmer serait du bruit.
    final (device, threadId) = deviceWithThread();
    device.opener
      ..canOpen = false
      ..canSave = false;
    device.store.insert(
      Build.message(
        threadId: threadId,
        body: '',
        attachments: [
          Build.attachment(
            id: 'part-exotique',
            mimeType: 'application/x-inconnu',
            fileName: 'truc.xyz',
          ),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);
    await tester.tap(find.byKey(const Key('attachment_part-exotique')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(device.opener.saved, ['part-exotique']);
    expect(find.byKey(const Key('attachmentSaved')), findsNothing);
  });

  /// Les coins de la vignette d'une image, tels qu'ils sont réellement
  /// découpés.
  BorderRadius imageRadiusOf(WidgetTester tester, String attachmentId) {
    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byKey(Key('attachment_$attachmentId')),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    return clip.borderRadius as BorderRadius;
  }

  BoxDecoration bubbleDecorationOf(WidgetTester tester, String messageId) =>
      tester.widget<Container>(find.byKey(Key('bubble_$messageId'))).decoration
          as BoxDecoration;

  testWidgets('une image reçue n\'est pas posée sur un fond de message', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.store.putAttachmentBytes(
      'part-nu',
      SampleImage.solid(width: 8, height: 6, argb: 0xFF5BB874),
    );
    device.store.insert(
      Build.message(
        id: 'photo-nue',
        threadId: threadId,
        body: '',
        attachments: [Build.attachment(id: 'part-nu', mimeType: 'image/png')],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    final decoration = bubbleDecorationOf(tester, 'photo-nue');
    // Aucun fond : l'image *est* la bulle, on ne la pose pas dessus.
    expect(decoration.color, Colors.transparent);
    // Et elle en prend les coins, plutôt qu'un rayon à elle.
    expect(imageRadiusOf(tester, 'part-nu'), decoration.borderRadius);
  });

  testWidgets('une légende ramène le fond, l\'image restant bord à bord', (
    tester,
  ) async {
    final (device, threadId) = deviceWithThread();
    device.store.insert(
      Build.message(
        id: 'photo-legendee',
        threadId: threadId,
        body: 'Les places',
        // Bien après le message d'ouverture du fil : seule dans sa salve, la
        // bulle a ses quatre coins arrondis, et c'est la légende — elle seule —
        // qui resserre ceux du bas de l'image.
        sentAt: DateTime(2026, 8, 25, 14),
        attachments: [
          Build.attachment(id: 'part-legende', mimeType: 'image/png'),
        ],
      ),
    );

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    // Le texte, lui, a besoin d'un fond pour se lire sur le fil.
    expect(
      bubbleDecorationOf(tester, 'photo-legendee').color,
      isNot(Colors.transparent),
    );
    // L'image garde les coins hauts de la bulle et resserre ceux du bas : le
    // message continue en dessous.
    final radius = imageRadiusOf(tester, 'part-legende');
    expect(radius.topLeft, const Radius.circular(20));
    expect(radius.bottomLeft, const Radius.circular(4));
    expect(radius.bottomRight, const Radius.circular(4));
  });

  testWidgets('les coins d\'une image suivent le groupement des bulles', (
    tester,
  ) async {
    // Deux photos envoyées coup sur coup : elles forment une salve et se
    // resserrent l'une vers l'autre, exactement comme deux bulles de texte.
    final (device, threadId) = deviceWithThread();
    for (final (index, id) in ['part-haut', 'part-bas'].indexed) {
      device.store.insert(
        Build.message(
          threadId: threadId,
          body: '',
          direction: MessageDirection.outgoing,
          sentAt: DateTime(2026, 8, 27, 10, index),
          // Deux images larges plutôt que carrées : deux carrés de la largeur
          // d'une bulle ne tiendraient pas dans la fenêtre du test, et la
          // première ne serait même pas construite.
          attachments: [
            Build.attachment(
              id: id,
              mimeType: 'image/png',
              width: 800,
              height: 200,
            ),
          ],
        ),
      );
    }

    await pumpPage(tester, ConversationPage(threadId: threadId), device: device);

    const round = Radius.circular(20);
    const tight = Radius.circular(4);

    final first = imageRadiusOf(tester, 'part-haut');
    expect(first.topRight, round, reason: 'ouvre la salve');
    expect(first.bottomRight, tight, reason: 'colle à la suivante');

    final second = imageRadiusOf(tester, 'part-bas');
    expect(second.topRight, tight, reason: 'colle à la précédente');
    expect(second.bottomRight, round, reason: 'ferme la salve');
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
