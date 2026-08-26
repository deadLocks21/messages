import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_compressor.service.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';

/// Ajoute au plateau de rédaction ce que l'utilisateur vient de choisir, et
/// fait en sorte que l'ensemble tienne dans un MMS.
///
/// Le contrôle de taille se fait **ici**, avant l'envoi : découvrir au retour
/// du MMSC que le message était trop lourd laisserait une bulle en échec sans
/// rien dire de réparable. Mieux vaut ajuster la pièce jointe pendant qu'elle
/// est encore retirable.
///
/// Le cas d'usage rend le plateau **complet** (ancien + nouveau) plutôt que la
/// seule sélection : le budget est global au message, et se répartit donc entre
/// toutes les pièces jointes à la fois.
class PickAttachmentsUseCase {
  final AttachmentPicker _picker;
  final AttachmentCompressor _compressor;
  final MmsConfiguration _configuration;

  const PickAttachmentsUseCase({
    required AttachmentPicker picker,
    required AttachmentCompressor compressor,
    required MmsConfiguration configuration,
  }) : _picker = picker,
       _compressor = compressor,
       _configuration = configuration;

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
    if (merged.length > MmsLimits.maxCount) {
      throw const TooManyAttachmentsException();
    }

    return fitToBudget(merged);
  }

  /// Fait entrer chaque pièce jointe dans le budget d'un MMS, en allégeant ce
  /// qui peut l'être.
  ///
  /// Chaque pièce part dans **son propre message** (cf. [SendMessageUseCase]) :
  /// le budget ne se partage donc pas, chacune en dispose entièrement. C'est
  /// tout l'intérêt du découpage — trois photos gardent chacune la qualité
  /// qu'elles auraient eue seules, au lieu d'un tiers.
  ///
  /// Une pièce déjà sous le budget n'est pas touchée : inutile de dégrader ce
  /// qui tenait déjà.
  Future<List<AttachmentDraft>> fitToBudget(List<AttachmentDraft> drafts) async {
    // La limite est celle de l'opérateur, pas une constante : c'est elle qui
    // détermine combien de qualité chaque image peut garder.
    final limits = await _configuration.limits();
    final budget = limits.contentBytes;

    final fitted = <AttachmentDraft>[];
    for (final draft in drafts) {
      if (draft.byteSize <= budget) {
        fitted.add(draft);
        continue;
      }
      // Ni une vidéo ni un PDF ne s'allègent : pour eux, trop lourd veut dire
      // trop lourd.
      if (!draft.isCompressible) throw AttachmentTooLargeException(limits);

      final compressed = await _compressor.compress(draft, targetBytes: budget);
      if (compressed == null) throw AttachmentTooLargeException(limits);
      // La compression vise une cible sans la garantir au kilooctet près.
      if (compressed.byteSize > budget) {
        throw AttachmentTooLargeException(limits);
      }
      fitted.add(compressed);
    }
    return fitted;
  }
}
