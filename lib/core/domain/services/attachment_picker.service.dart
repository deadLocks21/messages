import 'package:messages/core/domain/model/attachment.dart';

/// D'où vient une pièce jointe. Une entrée du panneau de rédaction — le même
/// panneau que celui de Google Messages.
enum AttachmentSource {
  /// Photos et vidéos déjà sur l'appareil.
  gallery,

  /// Prise de vue immédiate.
  camera,

  /// N'importe quel fichier (PDF, audio, archive…).
  files,

  /// Fiche de contact, envoyée en vCard.
  contactCard,
}

/// Port de **sélection** d'une pièce jointe.
///
/// Ouvrir la galerie, l'appareil photo ou le sélecteur de fichiers est une
/// affaire de plateforme : le domaine ne veut connaître que le résultat, une
/// liste d'[AttachmentDraft] prêts à partir. Une sélection annulée rend une
/// liste vide — ce n'est pas une erreur.
abstract interface class AttachmentPicker {
  Future<List<AttachmentDraft>> pick(AttachmentSource source);
}
