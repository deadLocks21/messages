import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';

/// Ajoute au plateau de rédaction ce que l'utilisateur vient de choisir.
///
/// Le contrôle de taille se fait **ici**, avant l'envoi : découvrir au retour
/// du MMSC que le message était trop lourd laisserait une bulle en échec sans
/// rien dire de réparable. Mieux vaut refuser la pièce jointe pendant qu'elle
/// est encore retirable.
///
/// Le cas d'usage rend le plateau **complet** (ancien + nouveau) plutôt que la
/// seule sélection : c'est l'état que l'appelant affiche, et il est validé d'un
/// bloc.
class PickAttachmentsUseCase {
  final AttachmentPicker _picker;

  const PickAttachmentsUseCase(AttachmentPicker picker) : _picker = picker;

  Future<List<AttachmentDraft>> execute(
    AttachmentSource source, {
    List<AttachmentDraft> current = const [],
  }) async {
    final picked = await _picker.pick(source);
    // Sélection annulée : le plateau ne bouge pas.
    if (picked.isEmpty) return current;

    final merged = [...current];
    for (final draft in picked) {
      if (!merged.contains(draft)) merged.add(draft);
    }

    if (merged.length > AttachmentLimits.maxCount) {
      throw const TooManyAttachmentsException();
    }
    final total = merged.fold<int>(0, (sum, a) => sum + a.byteSize);
    if (total > AttachmentLimits.maxTotalBytes) {
      throw const AttachmentTooLargeException();
    }
    return merged;
  }
}
