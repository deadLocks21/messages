import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/ui/pages/conversation/widgets/message_attachments.widget.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Une bulle de message.
///
/// Les coins suivent le groupement : ceux qui touchent la bulle précédente ou
/// suivante du même interlocuteur sont presque droits (4 px), les autres bien
/// arrondis (20 px) — la signature visuelle de Google Messages.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.entry,
    required this.onLongPress,
    this.onRetry,
  });

  final TimelineMessage entry;
  final VoidCallback onLongPress;
  final VoidCallback? onRetry;

  static const _round = Radius.circular(20);
  static const _tight = Radius.circular(4);

  /// Largeur maximale d'une bulle, relevée sur l'app d'origine : elle laisse
  /// toujours voir de quel côté elle penche.
  static const _maxWidthFactor = 0.82;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final message = entry.message;
    final outgoing = message.isOutgoing;
    final failed = message.status.hasFailed;

    final maxWidth = MediaQuery.sizeOf(context).width * _maxWidthFactor;

    final background = outgoing ? colors.bubbleOutgoing : colors.bubbleIncoming;
    final foreground = outgoing
        ? colors.onBubbleOutgoing
        : colors.onBubbleIncoming;

    final radius = _radius(outgoing);

    // Une image *est* la bulle : la poser sur un fond coloré lui ajoute un
    // liseré qui ne dit rien et rétrécit la photo d'autant. Le fond ne reste
    // que là où il sert à quelque chose — derrière du texte, ou derrière un
    // lecteur audio, qui ne se lisent pas sur un fil d'écran.
    final visualOnly =
        message.hasAttachments &&
        message.attachments.every((attachment) => attachment.kind.isVisual);
    final bare = visualOnly && message.body.isEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        entry.isFirstOfGroup ? 6 : 2,
        14,
        entry.isLastOfGroup ? 2 : 2,
      ),
      child: Column(
        crossAxisAlignment: outgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (entry.isFirstOfGroup && message.senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                message.senderName!,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ),
          Row(
            mainAxisAlignment: outgoing
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (failed && onRetry != null)
                IconButton(
                  key: Key('retry_${message.id}'),
                  tooltip: 'Réessayer',
                  icon: Icon(Icons.refresh, color: colors.danger, size: 20),
                  onPressed: onRetry,
                ),
              Flexible(
                child: GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    key: Key('bubble_${message.id}'),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: _padding(message, visualOnly: visualOnly),
                    decoration: BoxDecoration(
                      // Un envoi en échec garde son liseré rouge, même nu :
                      // c'est la seule chose qui dise que le message n'est pas
                      // parti.
                      color: bare
                          ? Colors.transparent
                          : (failed ? colors.surfaceAlt : background),
                      borderRadius: radius,
                      border: failed
                          ? Border.all(color: colors.danger, width: 1)
                          : null,
                    ),
                    // `start`, surtout pas `stretch` : une bulle se serre sur
                    // son contenu. L'étirer donnerait à « Bisous » la même
                    // largeur qu'à un paragraphe.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.hasAttachments)
                          MessageAttachments(
                            message: message,
                            foreground: failed
                                ? colors.textPrimary
                                : foreground,
                            background: failed ? colors.surfaceAlt : background,
                            maxWidth: visualOnly
                                ? maxWidth
                                : maxWidth - _attachmentPadding * 2,
                            // Les coins de la bulle deviennent ceux de l'image.
                            // Sous une légende, ceux du bas se resserrent : le
                            // message continue en dessous.
                            visualRadius: message.body.isEmpty
                                ? radius
                                : BorderRadius.only(
                                    topLeft: radius.topLeft,
                                    topRight: radius.topRight,
                                    bottomLeft: _tight,
                                    bottomRight: _tight,
                                  ),
                          ),
                        // Une légende sous ses pièces jointes retrouve le
                        // rembourrage qu'une bulle de texte a toujours : sans
                        // lui, elle collerait au bord de l'image.
                        if (message.body.isNotEmpty)
                          Padding(
                            padding: visualOnly
                                // La légende retrouve le rembourrage d'une
                                // bulle de texte : l'image, elle, va bord à
                                // bord.
                                ? const EdgeInsets.fromLTRB(14, 8, 14, 9)
                                : message.hasAttachments
                                ? const EdgeInsets.fromLTRB(6, 8, 6, 2)
                                : EdgeInsets.zero,
                            child: Text(
                              message.body,
                              style: TextStyle(
                                color: failed ? colors.textPrimary : foreground,
                                fontSize: 16,
                                height: 1.28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (entry.showStatus || failed)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
              child: Text(
                message.statusLabel,
                key: Key('status_${message.id}'),
                style: TextStyle(
                  fontSize: 12,
                  color: failed ? colors.danger : colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Le liseré qui reste autour d'une pièce jointe **non visuelle** — un
  /// lecteur audio, une ligne de fichier : assez pour que la bulle se devine
  /// autour, pas assez pour l'encadrer.
  static const _attachmentPadding = 4.0;

  /// Une bulle de texte respire ; une image ne se rembourre pas du tout — elle
  /// va bord à bord, et c'est sa propre découpe qui fait la bulle.
  EdgeInsets _padding(MessageDto message, {required bool visualOnly}) {
    if (visualOnly) return EdgeInsets.zero;
    if (message.hasAttachments) return const EdgeInsets.all(_attachmentPadding);
    return const EdgeInsets.symmetric(horizontal: 18, vertical: 9);
  }

  /// Coins arrondis côté « extérieur », resserrés côté salve.
  BorderRadius _radius(bool outgoing) {
    final first = entry.isFirstOfGroup;
    final last = entry.isLastOfGroup;
    if (outgoing) {
      return BorderRadius.only(
        topLeft: _round,
        bottomLeft: _round,
        topRight: first ? _round : _tight,
        bottomRight: last ? _round : _tight,
      );
    }
    return BorderRadius.only(
      topRight: _round,
      bottomRight: _round,
      topLeft: first ? _round : _tight,
      bottomLeft: last ? _round : _tight,
    );
  }
}
