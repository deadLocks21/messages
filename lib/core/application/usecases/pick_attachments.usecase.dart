import 'package:messages/core/application/services/logger_application.service.dart';
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
  final LoggerApplicationService _logger;

  const PickAttachmentsUseCase({
    required AttachmentPicker picker,
    required AttachmentCompressor compressor,
    required MmsConfiguration configuration,
    required LoggerApplicationService logger,
  }) : _picker = picker,
       _compressor = compressor,
       _configuration = configuration,
       _logger = logger;

  Future<List<AttachmentDraft>> execute(
    AttachmentSource source, {
    List<AttachmentDraft> current = const [],
  }) async {
    final List<AttachmentDraft> picked;
    try {
      picked = await _picker.pick(source);
    } catch (e, stack) {
      // Le sélecteur est du natif : il échoue pour des raisons qu'on ne voit
      // pas d'ici (permission média retirée, appareil photo occupé).
      await _logger.error(
        'attachment.pick_failed',
        attrs: {'attachment.source': source.name},
        error: e,
        stack: stack,
      );
      rethrow;
    }
    // Sélection annulée : le plateau ne bouge pas. C'est un non-événement, et
    // ça ne se journalise pas.
    if (picked.isEmpty) return current;

    await _logger.info(
      'attachment.picked',
      attrs: {
        'attachment.source': source.name,
        'attachments.count': picked.length,
        'attachments.bytes': picked.fold<int>(0, (sum, a) => sum + a.byteSize),
        'attachment.mime': picked.first.mimeType,
      },
    );

    final merged = [...current];
    for (final draft in picked) {
      if (!merged.contains(draft)) merged.add(draft);
    }
    if (merged.length > MmsLimits.maxCount) {
      await _logger.warn(
        'attachment.rejected',
        attrs: {
          'attachment.reason': 'too_many',
          'attachments.count': merged.length,
          'attachments.max': MmsLimits.maxCount,
        },
      );
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
      if (!draft.isCompressible) {
        await _rejectTooLarge(draft, budget, 'incompressible');
        throw AttachmentTooLargeException(limits);
      }

      final compressed = await _compressor.compress(draft, targetBytes: budget);
      if (compressed == null) {
        await _rejectTooLarge(draft, budget, 'compression_failed');
        throw AttachmentTooLargeException(limits);
      }
      // La compression vise une cible sans la garantir au kilooctet près.
      if (compressed.byteSize > budget) {
        await _rejectTooLarge(compressed, budget, 'still_too_large');
        throw AttachmentTooLargeException(limits);
      }
      // Le taux obtenu est ce qui dit si le budget opérateur lu est réaliste :
      // une image ramenée à un dixième de sa taille finit par se voir.
      await _logger.info(
        'attachment.compressed',
        attrs: {
          'attachment.mime': draft.mimeType,
          'attachment.bytes_before': draft.byteSize,
          'attachment.bytes_after': compressed.byteSize,
          'attachment.budget_bytes': budget,
        },
      );
      fitted.add(compressed);
    }
    return fitted;
  }

  Future<void> _rejectTooLarge(
    AttachmentDraft draft,
    int budget,
    String reason,
  ) => _logger.warn(
    'attachment.rejected',
    attrs: {
      'attachment.reason': reason,
      'attachment.mime': draft.mimeType,
      'attachment.bytes': draft.byteSize,
      'attachment.budget_bytes': budget,
    },
  );
}
