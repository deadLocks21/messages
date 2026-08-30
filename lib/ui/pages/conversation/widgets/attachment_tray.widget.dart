import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_thumbnail.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';
import 'package:messages/ui/providers/attachment_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Bandeau des pièces jointes choisies, posé juste au-dessus du champ de
/// rédaction.
///
/// Il n'apparaît que s'il porte quelque chose : un fil sans pièce jointe garde
/// exactement la mise en page d'avant. Chaque vignette a sa croix — retirer une
/// pièce jointe doit être aussi simple que de l'ajouter, avant l'envoi comme
/// après une erreur.
///
/// Un **vocal** n'y prend pas la forme d'une vignette : il n'a rien à montrer,
/// et une pastille carrée avec une icône de note ne dirait ni sa longueur, ni
/// ce qu'on y entend. Il prend donc la place d'un lecteur, comme dans la bulle
/// où il finira — et c'est le même lecteur, à l'octet près.
class AttachmentTrayBar extends ConsumerWidget {
  const AttachmentTrayBar({super.key, required this.threadId});

  final String threadId;

  static const _thumbnailSize = 76.0;

  /// Largeur du lecteur d'un vocal posé sur le plateau. Assez large pour que
  /// la piste se lise, assez étroite pour qu'une seconde pièce jointe reste
  /// visible à côté.
  static const _voiceWidth = 260.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(attachmentTrayProvider(threadId));
    if (drafts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      key: const Key('attachmentTray'),
      height: _thumbnailSize + 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        itemCount: drafts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return _Removable(
            threadId: threadId,
            draftId: draft.id,
            child: draft.kind == AttachmentKind.audio
                ? _TrayVoice(draft: draft, width: _voiceWidth)
                : _TrayThumbnail(
                    threadId: threadId,
                    draft: draft,
                    size: _thumbnailSize,
                  ),
          );
        },
      ),
    );
  }
}

/// La croix qui retire une pièce jointe du plateau, quelle que soit la forme
/// de ce qu'elle surmonte — vignette ou lecteur.
class _Removable extends ConsumerWidget {
  const _Removable({
    required this.threadId,
    required this.draftId,
    required this.child,
  });

  final String threadId;
  final String draftId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: colors.surface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            child: InkWell(
              key: Key('removeAttachment_$draftId'),
              onTap: () => ref
                  .read(attachmentTrayProvider(threadId).notifier)
                  .remove(draftId),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: colors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrayThumbnail extends ConsumerWidget {
  const _TrayThumbnail({
    required this.threadId,
    required this.draft,
    required this.size,
  });

  final String threadId;
  final AttachmentDraftDto draft;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref
        .watch(draftAttachmentBytesProvider(threadId, draft.id))
        .value;

    return Tooltip(
      message: '${draft.fileName} · ${draft.sizeLabel}',
      child: AttachmentThumbnail(
        kind: draft.kind,
        bytes: bytes,
        width: size,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
    );
  }
}

/// Un vocal en attente d'envoi : le lecteur qu'il aura dans sa bulle, sur le
/// fond d'une bulle envoyée.
///
/// Ce n'est pas un aperçu à part — c'est [AudioAttachment], le même widget que
/// dans le fil. Un vocal s'écoute d'une seule façon, avant comme après l'envoi.
class _TrayVoice extends StatelessWidget {
  const _TrayVoice({required this.draft, required this.width});

  final AttachmentDraftDto draft;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: Key('trayVoice_${draft.id}'),
      width: width,
      decoration: BoxDecoration(
        color: colors.bubbleOutgoing,
        borderRadius: BorderRadius.circular(26),
      ),
      alignment: Alignment.center,
      child: AudioAttachment(
        attachment: AttachmentDto.fromDraft(draft),
        foreground: colors.onBubbleOutgoing,
        background: colors.bubbleOutgoing,
        maxWidth: width,
      ),
    );
  }
}
