import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_thumbnail.widget.dart';
import 'package:messages/ui/providers/attachment_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Bandeau des pièces jointes choisies, posé juste au-dessus du champ de
/// rédaction.
///
/// Il n'apparaît que s'il porte quelque chose : un fil sans pièce jointe garde
/// exactement la mise en page d'avant. Chaque vignette a sa croix — retirer une
/// pièce jointe doit être aussi simple que de l'ajouter, avant l'envoi comme
/// après une erreur.
class AttachmentTrayBar extends ConsumerWidget {
  const AttachmentTrayBar({super.key, required this.threadId});

  final String threadId;

  static const _thumbnailSize = 76.0;

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
        itemBuilder: (context, index) => _TrayItem(
          threadId: threadId,
          draft: drafts[index],
          size: _thumbnailSize,
        ),
      ),
    );
  }
}

class _TrayItem extends ConsumerWidget {
  const _TrayItem({
    required this.threadId,
    required this.draft,
    required this.size,
  });

  final String threadId;
  final AttachmentDraftDto draft;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final bytes = ref
        .watch(draftAttachmentBytesProvider(threadId, draft.id))
        .value;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: '${draft.fileName} · ${draft.sizeLabel}',
          child: AttachmentThumbnail(
            kind: draft.kind,
            bytes: bytes,
            width: size,
            borderRadius: 14,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: colors.surface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            child: InkWell(
              key: Key('removeAttachment_${draft.id}'),
              onTap: () => ref
                  .read(attachmentTrayProvider(threadId).notifier)
                  .remove(draft.id),
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
