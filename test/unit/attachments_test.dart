import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/usecases/pick_attachments.usecase.dart';
import 'package:messages/core/application/usecases/send_message.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/sample_image.dart';
import 'package:messages/infrastructure/preferences/in_memory.draft.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

void main() {
  group('AttachmentKind', () {
    test('se déduit du type MIME', () {
      expect(AttachmentKind.fromMimeType('image/jpeg'), AttachmentKind.image);
      expect(AttachmentKind.fromMimeType('video/mp4'), AttachmentKind.video);
      expect(AttachmentKind.fromMimeType('audio/amr'), AttachmentKind.audio);
      expect(AttachmentKind.fromMimeType('text/x-vCard'), AttachmentKind.vcard);
      expect(
        AttachmentKind.fromMimeType('application/pdf'),
        AttachmentKind.file,
      );
    });

    test('un type inconnu reste un fichier, jamais une erreur', () {
      expect(AttachmentKind.fromMimeType('bidon'), AttachmentKind.file);
    });
  });

  group('AttachmentDto', () {
    test('affiche un poids lisible', () {
      expect(AttachmentDto.formatBytes(512), '512 o');
      expect(AttachmentDto.formatBytes(2048), '2 Ko');
      expect(AttachmentDto.formatBytes(1024 * 1024 + 512 * 1024), '1,5 Mo');
    });

    test('nomme une pièce jointe qui n\'a pas de nom', () {
      final dto = AttachmentDto.fromDomain(
        Attachment(id: 'part-1', mimeType: 'image/png'),
      );
      expect(dto.fileName, 'Image');
    });
  });

  group('MessageDto.previewText', () {
    test('un MMS sans légende s\'annonce par sa pièce jointe', () {
      final message = MessageDto.fromDomain(
        Build.message(
          body: '',
          attachments: [Build.attachment(mimeType: 'image/png')],
        ),
      );
      expect(message.previewText, 'Photo');
    });

    test('une légende est précédée du libellé', () {
      final message = MessageDto.fromDomain(
        Build.message(
          body: 'Regarde',
          attachments: [Build.attachment(mimeType: 'image/png')],
        ),
      );
      expect(message.previewText, 'Photo · Regarde');
    });

    test('plusieurs pièces jointes se comptent', () {
      final message = MessageDto.fromDomain(
        Build.message(
          body: '',
          attachments: [
            Build.attachment(id: 'a', mimeType: 'image/png'),
            Build.attachment(id: 'b', mimeType: 'application/pdf'),
          ],
        ),
      );
      expect(message.previewText, '2 pièces jointes');
    });

    test('un SMS garde son texte', () {
      final message = MessageDto.fromDomain(Build.message(body: 'Coucou'));
      expect(message.previewText, 'Coucou');
    });
  });

  group('PickAttachmentsUseCase', () {
    late InMemorySmsStore store;
    late InMemoryAttachmentPicker picker;
    late PickAttachmentsUseCase usecase;

    setUp(() {
      store = InMemorySmsStore();
      picker = InMemoryAttachmentPicker(store);
      usecase = PickAttachmentsUseCase(
        picker: picker,
        compressor: InMemoryAttachmentCompressor(store),
        configuration: InMemoryMmsConfiguration(),
        logger: testLogger(),
      );
    });

    test('ajoute la sélection au plateau existant', () async {
      final first = await usecase.execute(AttachmentSource.gallery);
      final both = await usecase.execute(
        AttachmentSource.files,
        current: first,
      );

      expect(first, hasLength(1));
      expect(both, hasLength(2));
      expect(both.last.mimeType, 'application/pdf');
      expect(picker.requested, [
        AttachmentSource.gallery,
        AttachmentSource.files,
      ]);
    });

    test('une sélection annulée laisse le plateau intact', () async {
      final current = await usecase.execute(AttachmentSource.gallery);
      picker.cancelNext = true;

      final after = await usecase.execute(
        AttachmentSource.camera,
        current: current,
      );

      expect(after, current);
    });

    test('refuse quand rien de compressible ne peut libérer de place', () async {
      // Un fichier — non compressible — occupe déjà tout le budget.
      final current = [
        Build.draft(
          mimeType: 'application/pdf',
          fileName: 'gros.pdf',
          byteSize: MmsLimits.fallback.maxTotalBytes,
        ),
      ];

      expect(
        () => usecase.execute(AttachmentSource.gallery, current: current),
        throwsA(isA<AttachmentTooLargeException>()),
      );
    });

    test('refuse trop de pièces jointes', () async {
      final current = List.generate(
        MmsLimits.maxCount,
        (i) => Build.draft(id: 'draft-$i', byteSize: 10),
      );

      expect(
        () => usecase.execute(AttachmentSource.gallery, current: current),
        throwsA(isA<TooManyAttachmentsException>()),
      );
    });
  });

  group('SendMessageUseCase avec pièces jointes', () {
    late InMemorySmsStore store;
    late SendMessageUseCase usecase;

    setUp(() {
      store = InMemorySmsStore();
      usecase = SendMessageUseCase(
        messages: InMemoryMessageRepository(store),
        drafts: InMemoryDraftRepository(),
        configuration: InMemoryMmsConfiguration(),
        logger: testLogger(),
      );
    });

    test('une photo sans texte est un message valide', () async {
      final sent = await usecase.execute(
        recipients: const ['+33612345678'],
        body: '',
        attachments: [Build.draft(mimeType: 'image/png')],
      );

      expect(sent.single.body, '');
      expect(sent.single.attachments, hasLength(1));
      expect(sent.single.attachments.single.kind, AttachmentKind.image);
    });

    test('un message vraiment vide reste refusé', () async {
      expect(
        () => usecase.execute(recipients: const ['+33612345678'], body: '  '),
        throwsA(isA<MessageSendFailedException>()),
      );
    });

    test('refuse un envoi au-delà de la taille admise', () async {
      expect(
        () => usecase.execute(
          recipients: const ['+33612345678'],
          body: 'Tiens',
          attachments: [
            Build.draft(byteSize: MmsLimits.fallback.maxTotalBytes + 1),
          ],
        ),
        throwsA(isA<AttachmentTooLargeException>()),
      );
    });

    test('les pièces jointes entrent dans le stock avec le message', () async {
      final picker = InMemoryAttachmentPicker(store);
      final drafts = await picker.pick(AttachmentSource.gallery);

      final sent = await usecase.execute(
        recipients: const ['+33612345678'],
        body: 'Regarde',
        attachments: drafts,
      );

      final stored = store.byId(sent.single.id)!;
      expect(stored.isMms, isTrue);
      // Le contenu suit la pièce jointe jusque dans le stock : c'est lui que
      // l'UI relira pour la vignette de la bulle.
      expect(store.bytesOf(stored.attachments.single.id), isNotNull);
    });

    test('chaque pièce jointe part dans son propre message', () async {
      // Le budget d'un MMS est fixe : regrouper trois photos diviserait leur
      // qualité par trois. Séparées, chacune en dispose entièrement.
      final sent = await usecase.execute(
        recipients: const ['+33612345678'],
        body: 'Les vacances',
        attachments: [
          Build.draft(id: 'a', mimeType: 'image/jpeg'),
          Build.draft(id: 'b', mimeType: 'image/jpeg'),
          Build.draft(id: 'c', mimeType: 'image/jpeg'),
        ],
      );

      expect(sent, hasLength(3));
      for (final message in sent) {
        expect(message.attachments, hasLength(1));
      }
      // La légende accompagne le premier, une seule fois : la répéter
      // donnerait l'impression d'un bégaiement.
      expect(sent.first.body, 'Les vacances');
      expect(sent.skip(1).map((m) => m.body), everyElement(isEmpty));
    });

    test('une pièce jointe unique reste un seul message', () async {
      final sent = await usecase.execute(
        recipients: const ['+33612345678'],
        body: 'Regarde',
        attachments: [Build.draft(mimeType: 'image/jpeg')],
      );

      expect(sent, hasLength(1));
      expect(sent.single.body, 'Regarde');
    });

    test('le fil annonce la nature du dernier MMS', () async {
      await usecase.execute(
        recipients: const ['+33612345678'],
        body: '',
        attachments: [Build.draft(mimeType: 'video/mp4')],
      );

      expect(store.conversations().single.lastAttachmentKind,
          AttachmentKind.video);
    });
  });

  group('SampleImage', () {
    test('produit un PNG reconnaissable et de taille cohérente', () {
      final bytes = SampleImage.solid(width: 4, height: 3, argb: 0xFF112233);

      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      // La largeur est écrite en big-endian à l'offset 16, dans l'IHDR.
      expect(bytes[19], 4);
      expect(bytes[23], 3);
    });
  });
}
