import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_opener.service.dart';
import 'package:messages/ui/pages/conversation/attachment_viewer.page.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_thumbnail.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/ui/providers/attachment_providers.dart';

/// Les pièces jointes d'un message, telles qu'elles s'empilent dans sa bulle.
///
/// Trois traitements, comme dans l'app d'origine :
/// - **visuel** (image, vidéo) : la pièce jointe *est* la bulle — elle occupe
///   toute la largeur disponible, sans le rembourrage qui entourerait du texte ;
/// - **sonore** : un lecteur, parce qu'un vocal ne se lit pas, il s'écoute ;
/// - **le reste** (fichier, contact) : une ligne icône + nom + poids, parce
///   qu'il n'y a rien à montrer d'un PDF.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({
    super.key,
    required this.message,
    required this.foreground,
    required this.maxWidth,
    required this.visualRadius,
  });

  /// Le message entier, et pas seulement sa liste de pièces jointes : ouvrir
  /// une photo en grand affiche aussi de qui elle vient et de quand elle date.
  final MessageDto message;

  /// Couleur du texte de la bulle qui les porte : une pièce jointe reçue et une
  /// pièce jointe envoyée ne se lisent pas sur le même fond.
  final Color foreground;

  final double maxWidth;

  /// Coins d'une pièce jointe visuelle : ceux de la bulle qui la porte, une
  /// image n'étant pas posée sur un message mais en tenant lieu.
  final BorderRadius visualRadius;

  List<AttachmentDto> get attachments => message.attachments;

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
            // Exhaustif à dessein : une nature de pièce jointe qui
            // apparaîtrait plus tard doit obliger à décider de son sort, pas
            // retomber silencieusement sur la ligne de fichier.
            child: switch (attachment.kind) {
              AttachmentKind.image || AttachmentKind.video => _VisualAttachment(
                attachment: attachment,
                message: message,
                maxWidth: maxWidth,
                radius: visualRadius,
              ),
              AttachmentKind.audio => AudioAttachment(
                key: Key('attachment_${attachment.id}'),
                attachment: attachment,
                foreground: foreground,
                maxWidth: maxWidth,
              ),
              AttachmentKind.vcard || AttachmentKind.file => _FileAttachment(
                attachment: attachment,
                foreground: foreground,
              ),
            },
          ),
      ],
    );
  }
}

class _VisualAttachment extends ConsumerWidget {
  const _VisualAttachment({
    required this.attachment,
    required this.message,
    required this.maxWidth,
    required this.radius,
  });

  final AttachmentDto attachment;
  final MessageDto message;
  final double maxWidth;
  final BorderRadius radius;

  /// Une image très haute serait une colonne interminable dans le fil : on la
  /// borne, quitte à la recadrer, comme le fait l'app d'origine.
  static const _maxAspectRatio = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seule une image se décode ici. Demander ses octets à une vidéo ferait
    // traverser des mégaoctets au canal pour n'afficher, au bout du compte,
    // qu'une pastille de lecture.
    final isImage = attachment.kind == AttachmentKind.image;
    final bytes = isImage
        ? ref.watch(attachmentBytesProvider(attachment.id)).value
        : null;
    final ratio = attachment.aspectRatio;
    final width = maxWidth;
    final height = ratio == null
        ? width
        : width / ratio.clamp(_maxAspectRatio, 3.0);

    final thumbnail = AttachmentThumbnail(
      key: Key('attachment_${attachment.id}'),
      kind: attachment.kind,
      bytes: bytes,
      width: width,
      height: height,
      borderRadius: radius,
    );

    // La vignette est recadrée à la largeur de la bulle : une photo en
    // portrait y perd ses bords, un texte photographié y devient illisible.
    // L'appui la rouvre entière.
    //
    // Une vidéo, elle, n'a rien à rouvrir ici — ses octets ne sont jamais lus,
    // et l'app ne sait pas la jouer. L'appui la confie au lecteur du système.
    if (!isImage) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openElsewhere(context, ref, attachment),
        child: thumbnail,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // `onTap` seul : l'appui long reste celui de la bulle (actions du
      // message), le premier laissant la main au second dans l'arène.
      onTap: () => AttachmentViewerPage.open(
        context,
        attachment: attachment,
        message: message,
      ),
      child: Hero(
        tag: AttachmentViewerPage.heroTagFor(attachment.id),
        child: thumbnail,
      ),
    );
  }
}

/// Confie [attachment] à l'application du système la plus adaptée.
///
/// Quand il n'y en a aucune, la pièce jointe n'est pas perdue pour autant :
/// l'app propose de l'enregistrer. Un appui qui ne produirait rien du tout
/// laisserait croire à une bulle cassée, là où il ne s'agit que d'un type que
/// personne, sur cet appareil, ne sait ouvrir.
Future<void> _openElsewhere(
  BuildContext context,
  WidgetRef ref,
  AttachmentDto attachment,
) async {
  final messenger = ScaffoldMessenger.of(context);
  // Le service est saisi maintenant : le bandeau survit à la bulle si le fil
  // défile, et son action ne pourra plus rien demander à un `ref` démonté.
  final opener = ref.read(attachmentOpenerProvider);

  if (await opener.open(
    attachment.id,
    mimeType: attachment.mimeType,
    fileName: attachment.fileName,
  )) {
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      key: const Key('noAppForAttachment'),
      content: const Text('Aucune application ne peut ouvrir ce fichier'),
      action: SnackBarAction(
        label: 'Enregistrer',
        onPressed: () => _saveElsewhere(messenger, opener, attachment),
      ),
    ),
  );
}

Future<void> _saveElsewhere(
  ScaffoldMessengerState messenger,
  AttachmentOpener opener,
  AttachmentDto attachment,
) async {
  final saved = await opener.save(
    attachment.id,
    mimeType: attachment.mimeType,
    fileName: attachment.fileName,
  );
  // Renoncer n'appelle pas de confirmation : l'utilisateur sait ce qu'il vient
  // de faire.
  if (!saved) return;
  messenger.showSnackBar(
    const SnackBar(
      key: Key('attachmentSaved'),
      content: Text('Pièce jointe enregistrée'),
    ),
  );
}

class _FileAttachment extends ConsumerWidget {
  const _FileAttachment({required this.attachment, required this.foreground});

  final AttachmentDto attachment;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Un PDF, une vCard : l'app ne sait pas les montrer, et le système a
      // déjà, pour chacun, l'application que l'utilisateur a choisie.
      onTap: () => _openElsewhere(context, ref, attachment),
      child: Row(
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
      ),
    );
  }
}
