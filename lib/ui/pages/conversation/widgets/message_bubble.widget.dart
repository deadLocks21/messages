import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
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
                    padding: _padding(message.attachments.isNotEmpty),
                    decoration: BoxDecoration(
                      color: failed ? colors.surfaceAlt : background,
                      borderRadius: _radius(outgoing),
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
                            attachments: message.attachments,
                            foreground: failed
                                ? colors.textPrimary
                                : foreground,
                            maxWidth: maxWidth - _attachmentPadding * 2,
                          ),
                        // Une légende sous ses pièces jointes retrouve le
                        // rembourrage qu'une bulle de texte a toujours : sans
                        // lui, elle collerait au bord de l'image.
                        if (message.body.isNotEmpty)
                          Padding(
                            padding: message.hasAttachments
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

  /// Le liseré qui reste autour d'une pièce jointe : assez pour que la bulle
  /// se devine derrière l'image, pas assez pour l'encadrer.
  static const _attachmentPadding = 4.0;

  /// Une bulle de texte respire ; une bulle qui porte une image se resserre
  /// sur elle, sinon l'image flotterait dans un cadre coloré.
  EdgeInsets _padding(bool hasAttachments) => hasAttachments
      ? const EdgeInsets.all(_attachmentPadding)
      : const EdgeInsets.symmetric(horizontal: 18, vertical: 9);

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
