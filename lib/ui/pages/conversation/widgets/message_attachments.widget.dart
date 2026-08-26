import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_thumbnail.widget.dart';
import 'package:messages/ui/providers/attachment_providers.dart';

/// Les pièces jointes d'un message, telles qu'elles s'empilent dans sa bulle.
///
/// Deux traitements, comme dans l'app d'origine :
/// - **visuel** (image, vidéo) : la pièce jointe *est* la bulle — elle occupe
///   toute la largeur disponible, sans le rembourrage qui entourerait du texte ;
/// - **non visuel** (fichier, contact, audio) : une ligne icône + nom + poids,
///   parce qu'il n'y a rien à montrer d'un PDF.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({
    super.key,
    required this.attachments,
    required this.foreground,
    required this.maxWidth,
  });

  final List<AttachmentDto> attachments;

  /// Couleur du texte de la bulle qui les porte : une pièce jointe reçue et une
  /// pièce jointe envoyée ne se lisent pas sur le même fond.
  final Color foreground;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Les enfants portent leur propre largeur : rien à étirer ici non plus,
    // sinon la bulle se remettrait à occuper toute la place disponible.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: EdgeInsets.only(
              bottom: attachment == attachments.last ? 0 : 6,
            ),
            child: attachment.kind.isVisual
                ? _VisualAttachment(attachment: attachment, maxWidth: maxWidth)
                : _FileAttachment(
                    attachment: attachment,
                    foreground: foreground,
                  ),
          ),
      ],
    );
  }
}

class _VisualAttachment extends ConsumerWidget {
  const _VisualAttachment({required this.attachment, required this.maxWidth});

  final AttachmentDto attachment;
  final double maxWidth;

  /// Une image très haute serait une colonne interminable dans le fil : on la
  /// borne, quitte à la recadrer, comme le fait l'app d'origine.
  static const _maxAspectRatio = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seule une image se décode ici. Demander ses octets à une vidéo ferait
    // traverser des mégaoctets au canal pour n'afficher, au bout du compte,
    // qu'une pastille de lecture.
    final bytes = attachment.kind == AttachmentKind.image
        ? ref.watch(attachmentBytesProvider(attachment.id)).value
        : null;
    final ratio = attachment.aspectRatio;
    final width = maxWidth;
    final height = ratio == null
        ? width
        : width / ratio.clamp(_maxAspectRatio, 3.0);

    return AttachmentThumbnail(
      key: Key('attachment_${attachment.id}'),
      kind: attachment.kind,
      bytes: bytes,
      width: width,
      height: height,
      borderRadius: 16,
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment, required this.foreground});

  final AttachmentDto attachment;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('attachment_${attachment.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          AttachmentThumbnail.iconFor(attachment.kind),
          size: 28,
          color: foreground,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground, fontSize: 15),
              ),
              Text(
                attachment.sizeLabel,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
