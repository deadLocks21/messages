import 'dart:typed_data';

import 'package:messages/core/domain/model/attachment.dart';

/// Port de **lecture** des octets d'une pièce jointe.
///
/// Séparé de [MessageRepository] parce qu'il a un tout autre rythme : les
/// messages se listent, les octets se demandent vignette par vignette, au
/// moment où elles entrent à l'écran.
abstract interface class AttachmentRepository {
  /// Contenu d'une pièce jointe du stock, désignée par l'identifiant de sa
  /// partie. Null si la partie a disparu.
  Future<Uint8List?> bytesOf(String attachmentId);

  /// Contenu d'une pièce jointe en cours de rédaction, pour sa vignette.
  Future<Uint8List?> draftBytesOf(AttachmentDraft draft);

  /// Libère ce qu'une sélection a laissé derrière elle (photo prise puis
  /// retirée du plateau, copie temporaire d'une URI de contenu). Sans effet sur
  /// un fichier que l'app ne possède pas.
  Future<void> discardDraft(AttachmentDraft draft);
}
