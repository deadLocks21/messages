import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/usecases/pick_attachments.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

import '../builders/builders.dart';

void main() {
  group('MmsLimits.fromCarrier', () {
    test('retient ce que publie l\'opérateur', () {
      expect(
        MmsLimits.fromCarrier(1024 * 1024).maxTotalBytes,
        1024 * 1024,
      );
    });

    test('retombe sur le défaut AOSP quand rien n\'est publié', () {
      expect(MmsLimits.fromCarrier(null), MmsLimits.fallback);
      expect(MmsLimits.fallback.maxTotalBytes, 300 * 1024);
    });

    test('écarte les valeurs aberrantes', () {
      // Une configuration à zéro rendrait l'envoi impossible ; une à 500 Mo
      // ferait exploser la mémoire au premier décodage.
      expect(MmsLimits.fromCarrier(0), MmsLimits.fallback);
      expect(MmsLimits.fromCarrier(-1), MmsLimits.fallback);
      expect(MmsLimits.fromCarrier(500 * 1024 * 1024), MmsLimits.fallback);
    });

    test('réserve de la place pour l\'enveloppe', () {
      final limits = MmsLimits.fromCarrier(600 * 1024);
      expect(limits.contentBytes, lessThan(limits.maxTotalBytes));
    });
  });

  group('Budget piloté par l\'opérateur', () {
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

    /// Une photo dont la définition dépasse les deux budgets comparés : c'est
    /// la seule façon de voir la limite peser sur le résultat.
    AttachmentDraft photo() => Build.draft(
      fileName: 'PHOTO.jpg',
      mimeType: 'image/jpeg',
      byteSize: 4 * 1024 * 1024,
      width: 640,
      height: 480,
    );

    test('un opérateur généreux laisse plus de qualité', () async {
      configuration.value = MmsLimits.fromCarrier(300 * 1024);
      final avare = await usecase.fitToBudget([photo()]);

      configuration.value = MmsLimits.fromCarrier(2 * 1024 * 1024);
      final genereux = await usecase.fitToBudget([photo()]);

      // C'est tout l'intérêt de lire la configuration plutôt que de la coder
      // en dur : la même photo garde davantage de pixels.
      expect(genereux.single.byteSize, greaterThan(avare.single.byteSize));
    });

    test('chaque plateau respecte la limite annoncée', () async {
      for (final octets in [300 * 1024, 600 * 1024, 2 * 1024 * 1024]) {
        configuration.value = MmsLimits.fromCarrier(octets);
        final fitted = await usecase.fitToBudget([photo(), photo()]);
        final total = fitted.fold<int>(0, (sum, d) => sum + d.byteSize);
        expect(total, lessThanOrEqualTo(configuration.value.contentBytes));
      }
    });

    test('le refus annonce la limite réellement lue', () async {
      configuration.value = MmsLimits.fromCarrier(300 * 1024);
      final pdf = Build.draft(
        mimeType: 'application/pdf',
        fileName: 'gros.pdf',
        byteSize: 5 * 1024 * 1024,
      );

      // « Trop lourd » sans dire de combien ne dit pas quoi faire.
      await expectLater(
        usecase.fitToBudget([pdf]),
        throwsA(
          isA<AttachmentTooLargeException>()
              .having((e) => e.limits.maxTotalBytes, 'limite', 300 * 1024)
              .having((e) => e.message, 'message', contains('300 Ko')),
        ),
      );
    });
  });
}
