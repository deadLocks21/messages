import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/usecases/pick_attachments.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

/// Une photo d'appareil : plusieurs mégaoctets, très au-delà d'un MMS.
AttachmentDraft cameraPhoto({int megapixels = 12}) => Build.draft(
  fileName: 'PHOTO_20260826.jpg',
  mimeType: 'image/jpeg',
  byteSize: megapixels * 350 * 1024,
);

void main() {
  late InMemorySmsStore store;
  late InMemoryMmsConfiguration configuration;
  late PickAttachmentsUseCase usecase;

  setUp(() {
    store = InMemorySmsStore();
    configuration = InMemoryMmsConfiguration();
    usecase = PickAttachmentsUseCase(
      picker: InMemoryAttachmentPicker(store),
      compressor: InMemoryAttachmentCompressor(store),
      configuration: configuration,
    );
  });

  /// Chaque pièce part seule dans son message : c'est **chacune** qui doit
  /// tenir dans le budget, pas leur somme.
  void expectEachFitsBudget(List<AttachmentDraft> drafts) {
    for (final draft in drafts) {
      expect(draft.byteSize, lessThanOrEqualTo(MmsLimits.fallback.contentBytes));
    }
  }

  group('Compression des pièces jointes', () {
    test('une photo d\'appareil est ramenée dans le budget', () async {
      // Le cas qui rendait la source « Appareil photo » inutilisable : la photo
      // était refusée telle quelle, sans recours.
      final fitted = await usecase.fitToBudget([cameraPhoto()]);

      expectEachFitsBudget(fitted);
      expect(fitted.single.byteSize, lessThan(cameraPhoto().byteSize));
    });

    test('la compression produit des octets réels, pas une promesse', () async {
      final fitted = await usecase.fitToBudget([cameraPhoto()]);

      final bytes = store.draftBytesOf(fitted.single.id);
      expect(bytes, isNotNull);
      expect(bytes!.length, fitted.single.byteSize);
    });

    test('une image qui tient déjà n\'est pas dégradée', () async {
      final petite = Build.draft(byteSize: 40 * 1024);

      final fitted = await usecase.fitToBudget([petite]);

      expect(fitted.single.uri, petite.uri);
      expect(fitted.single.byteSize, petite.byteSize);
    });

    test('chaque photo dispose du budget entier', () async {
      // Elles partiront dans trois messages distincts : le budget ne se
      // partage pas, et aucune n'est dégradée pour faire de la place aux
      // autres.
      final fitted = await usecase.fitToBudget([
        cameraPhoto(),
        cameraPhoto(),
        cameraPhoto(),
      ]);

      expect(fitted, hasLength(3));
      expectEachFitsBudget(fitted);
    });

    test('ajouter une photo n\'en dégrade pas les précédentes', () async {
      // C'était le prix du budget partagé : la troisième photo obligeait à
      // recomprimer les deux premières. Elles ne se gênent plus.
      final une = await usecase.fitToBudget([cameraPhoto()]);
      final trois = await usecase.fitToBudget([
        ...une,
        cameraPhoto(),
        cameraPhoto(),
      ]);

      expect(trois.first.byteSize, une.single.byteSize);
    });

    test('on repart toujours de l\'original, jamais du déjà compressé', () async {
      // Sans cela, ajouter une troisième photo recompresserait les deux
      // premières à partir de leur version compressée, et la dégradation
      // s'accumulerait à chaque ajout.
      final original = cameraPhoto();
      final une = await usecase.fitToBudget([original]);
      final trois = await usecase.fitToBudget([...une, cameraPhoto(), cameraPhoto()]);

      for (final draft in trois) {
        expect(draft.sourceUri, isNot(startsWith('memory://compressed-')));
      }
      expect(une.single.sourceUri, original.uri);
    });

    test('un fichier non compressible garde sa taille', () async {
      final pdf = Build.draft(
        mimeType: 'application/pdf',
        fileName: 'billet.pdf',
        byteSize: 120 * 1024,
      );

      final fitted = await usecase.fitToBudget([pdf, cameraPhoto()]);

      final resultatPdf = fitted.firstWhere((d) => d.mimeType == 'application/pdf');
      expect(resultatPdf.byteSize, pdf.byteSize);
      expectEachFitsBudget(fitted);
    });

    test('un fichier seul trop lourd est refusé — rien à comprimer', () async {
      final pdf = Build.draft(
        mimeType: 'application/pdf',
        fileName: 'gros.pdf',
        byteSize: 2 * 1024 * 1024,
      );

      expect(
        () => usecase.fitToBudget([pdf]),
        throwsA(isA<AttachmentTooLargeException>()),
      );
    });

    test('la sélection passe par le budget', () async {
      // Le chemin complet : choisir, puis tenir dans l'enveloppe.
      final fitted = await usecase.execute(
        AttachmentSource.camera,
        current: [cameraPhoto(), cameraPhoto()],
      );

      expectEachFitsBudget(fitted);
    });
  });
}
