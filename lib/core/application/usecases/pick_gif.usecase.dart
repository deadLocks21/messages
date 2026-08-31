import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/gif.dart';
import 'package:messages/core/domain/services/media_downloader.service.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';

/// Fait d'un GIF du catalogue une pièce jointe qui tiendra dans le MMS.
///
/// C'est le pendant de [PickAttachmentsUseCase] pour une source qui n'est pas
/// un écran du système, et il fait le même travail — faire entrer ce qui a été
/// choisi dans le budget de l'opérateur — mais **dans l'autre sens** :
///
/// - une photo se choisit puis s'allège ; le fichier existe d'abord, et le
///   compresseur le rattrape ;
/// - un GIF se **choisit à la bonne taille**, parce qu'il n'y a rien à
///   rattraper : le ré-encoder le figerait, et un GIF figé n'est plus un GIF.
///   Le catalogue en sert plusieurs déclinaisons, on prend la plus belle qui
///   tient, et c'est **elle seule** qu'on télécharge.
///
/// D'où l'ordre des opérations : lire le budget, choisir, puis seulement
/// télécharger. Ce qui ne rentre pas ne descend jamais du réseau.
class PickGifUseCase {
  final MediaDownloader _downloader;
  final MmsConfiguration _configuration;
  final LoggerApplicationService _logger;

  const PickGifUseCase({
    required MediaDownloader downloader,
    required MmsConfiguration configuration,
    required LoggerApplicationService logger,
  }) : _downloader = downloader,
       _configuration = configuration,
       _logger = logger;

  Future<AttachmentDraft> execute(Gif gif) async {
    // La limite est celle de l'opérateur, lue et mise en cache — la même que
    // pour une photo. C'est elle qui décide de la finesse du GIF envoyé.
    final limits = await _configuration.limits();
    final budget = limits.contentBytes;

    final rendition = gif.bestWithin(budget);
    if (rendition == null) {
      // Même le timbre-poste déborde : c'est un refus franc, comme celui d'une
      // vidéo. Le dire maintenant laisse encore le choix d'un autre GIF.
      await _logger.warn(
        'gif.rejected',
        attrs: {
          'attachment.reason': 'no_rendition_fits',
          'gif.id': gif.id,
          'gif.smallest_bytes': gif.renditions.last.byteSize,
          'attachment.budget_bytes': budget,
        },
      );
      throw AttachmentTooLargeException(limits);
    }

    final AttachmentDraft draft;
    try {
      draft = await _downloader.download(
        rendition.url,
        mimeType: Gif.sentMimeType,
        fileName: _fileNameFor(gif.description),
      );
    } catch (e, stack) {
      // Le catalogue est au bout du réseau : il échoue pour des raisons qu'on
      // ne voit pas d'ici (hors ligne, quota, adresse périmée).
      await _logger.error(
        'gif.download_failed',
        attrs: {'gif.id': gif.id, 'gif.bytes': rendition.byteSize},
        error: e,
        stack: stack,
      );
      rethrow;
    }

    // Le poids annoncé et le poids reçu ne coïncident pas toujours. Celui qui
    // compte est celui du fichier, et c'est le seul moment où on l'apprend.
    if (draft.byteSize > budget) {
      await _logger.warn(
        'gif.rejected',
        attrs: {
          'attachment.reason': 'downloaded_too_large',
          'gif.id': gif.id,
          'attachment.bytes': draft.byteSize,
          'attachment.budget_bytes': budget,
        },
      );
      throw AttachmentTooLargeException(limits);
    }

    await _logger.info(
      'gif.picked',
      attrs: {
        'gif.id': gif.id,
        'gif.width': rendition.width,
        'gif.height': rendition.height,
        'attachment.bytes': draft.byteSize,
        'attachment.budget_bytes': budget,
        // Combien de déclinaisons ont dû être écartées : c'est ce qui dit si
        // le budget lu de l'opérateur est réaliste ou beaucoup trop bas.
        'gif.renditions_skipped': gif.renditions.indexOf(rendition),
      },
    );
    return draft;
  }

  /// Le nom du fichier qui arrivera chez le destinataire.
  ///
  /// Tiré de ce que le catalogue dit du GIF (« Happy Dog Day GIF ») plutôt que
  /// de son identifiant : `happy-dog-day.gif` se retrouve dans une galerie,
  /// `AAAADS8n1s.gif` non.
  static String _fileNameFor(String description) {
    final slug = description
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    // Un descriptif vide ou tout en idéogrammes ne laisse rien à raboter : le
    // nom générique vaut mieux qu'un fichier nommé « .gif ».
    final stem = slug.isEmpty ? 'gif' : slug;
    return '${stem.length > 48 ? stem.substring(0, 48) : stem}.gif';
  }
}
