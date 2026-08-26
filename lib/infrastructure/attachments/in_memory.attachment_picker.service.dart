import 'dart:typed_data';

import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/sample_image.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';
import 'package:uuid/uuid.dart';

/// Sélecteur simulé : ni galerie, ni appareil photo, ni disque.
///
/// Chaque source rend une pièce jointe plausible et **réellement lisible** —
/// une image unie pour la galerie et l'appareil photo, une vCard pour un
/// contact, un PDF minimal pour un fichier. Le contenu est déposé dans le stock
/// simulé, qui le servira ensuite comme le ferait `content://mms/part`.
///
/// [cancelNext] simule l'utilisateur qui referme le sélecteur sans rien
/// choisir : le cas que l'UI doit traiter sans rien changer au plateau.
class InMemoryAttachmentPicker implements AttachmentPicker {
  final InMemorySmsStore _store;
  final Uuid _uuid = const Uuid();

  /// Quand vrai, la prochaine sélection rend une liste vide, puis le drapeau
  /// retombe.
  bool cancelNext;

  /// Sources demandées, dans l'ordre — ce que vérifient les tests d'UI.
  final List<AttachmentSource> requested = [];

  InMemoryAttachmentPicker(this._store, {this.cancelNext = false});

  @override
  Future<List<AttachmentDraft>> pick(AttachmentSource source) async {
    requested.add(source);
    if (cancelNext) {
      cancelNext = false;
      return const [];
    }
    return [_draftFor(source)];
  }

  AttachmentDraft _draftFor(AttachmentSource source) => switch (source) {
    AttachmentSource.gallery => _image('IMG_20260826.png', 0xFF5BB874),
    AttachmentSource.camera => _image('PHOTO_20260826.png', 0xFF5C93F5),
    AttachmentSource.files => _binary(
      fileName: 'Billet.pdf',
      mimeType: 'application/pdf',
      // En-tête PDF minimal : de quoi être reconnu pour ce qu'il est.
      bytes: Uint8List.fromList('%PDF-1.4\n% doublure\n'.codeUnits),
    ),
    AttachmentSource.contactCard => _binary(
      fileName: 'Camille Rousseau.vcf',
      mimeType: 'text/x-vcard',
      bytes: Uint8List.fromList(
        'BEGIN:VCARD\r\nVERSION:3.0\r\n'
                'FN:Camille Rousseau\r\nTEL:+33612345678\r\nEND:VCARD\r\n'
            .codeUnits,
      ),
    ),
  };

  AttachmentDraft _image(String fileName, int argb) {
    const width = 320;
    const height = 240;
    final bytes = SampleImage.solid(width: width, height: height, argb: argb);
    return _register(
      AttachmentDraft(
        id: _uuid.v4(),
        uri: 'memory://$fileName',
        mimeType: 'image/png',
        fileName: fileName,
        byteSize: bytes.length,
        width: width,
        height: height,
      ),
      bytes,
    );
  }

  AttachmentDraft _binary({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) => _register(
    AttachmentDraft(
      id: _uuid.v4(),
      uri: 'memory://$fileName',
      mimeType: mimeType,
      fileName: fileName,
      byteSize: bytes.length,
    ),
    bytes,
  );

  AttachmentDraft _register(AttachmentDraft draft, Uint8List bytes) {
    _store.registerDraft(draft, bytes);
    return draft;
  }
}
