import 'package:messages/core/domain/model/attachment.dart';

/// Port d'**allègement** d'une pièce jointe trop lourde pour un MMS.
///
/// Une photo d'appareil pèse plusieurs mégaoctets, un MMS quelques centaines
/// de kilooctets : sans cette étape, la source « Appareil photo » ne servirait
/// à rien. Réduire une image est une affaire de plateforme (décodage,
/// rééchantillonnage, ré-encodage), d'où ce port.
abstract interface class AttachmentCompressor {
  /// Ramène [draft] sous [targetBytes].
  ///
  /// Repart de `draft.sourceUri` — l'original — et non de ce qui a déjà été
  /// compressé, pour qu'un ajout successif ne dégrade pas ce qui était déjà là.
  ///
  /// Rend `null` quand la cible est hors d'atteinte : à ce moment-là, même très
  /// dégradée, l'image ne tiendrait pas. C'est un refus, pas une erreur.
  Future<AttachmentDraft?> compress(
    AttachmentDraft draft, {
    required int targetBytes,
  });
}
