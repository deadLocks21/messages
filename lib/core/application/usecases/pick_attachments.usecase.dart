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

  /// Fait entrer le plateau dans le budget d'un MMS, en allégeant ce qui peut
  /// l'être.
  ///
  /// La répartition est simple et explicable : ce qui ne se comprime pas est
  /// pris tel quel, et le reste du budget se partage à parts égales entre les
  /// images. Une image déjà sous sa part n'est pas touchée — inutile de
  /// dégrader une vignette qui tenait déjà.
  Future<List<AttachmentDraft>> fitToBudget(List<AttachmentDraft> drafts) async {
    // La limite est celle de l'opérateur, pas une constante : c'est elle qui
    // détermine combien de qualité chaque image peut garder.
    final limits = await _configuration.limits();
    final budget = limits.contentBytes;
    if (_totalOf(drafts) <= budget) return drafts;

    final compressible = drafts.where((d) => d.isCompressible).toList();
    if (compressible.isEmpty) throw AttachmentTooLargeException(limits);

    final fixed = _totalOf(drafts.where((d) => !d.isCompressible));
    final remaining = budget - fixed;
    // Ce qui ne se comprime pas mange déjà tout : rien à négocier.
    if (remaining <= 0) throw AttachmentTooLargeException(limits);

    final share = remaining ~/ compressible.length;
    final fitted = <AttachmentDraft>[];
    for (final draft in drafts) {
      if (!draft.isCompressible || draft.byteSize <= share) {
        fitted.add(draft);
        continue;
      }
      final compressed = await _compressor.compress(draft, targetBytes: share);
      if (compressed == null) throw AttachmentTooLargeException(limits);
      fitted.add(compressed);
    }

    // La compression vise une cible sans la garantir au kilooctet près : on
    // vérifie le total plutôt que de faire confiance à chaque pièce.
    if (_totalOf(fitted) > budget) {
      throw AttachmentTooLargeException(limits);
    }
    return fitted;
  }

  int _totalOf(Iterable<AttachmentDraft> drafts) =>
      drafts.fold<int>(0, (sum, a) => sum + a.byteSize);
}
