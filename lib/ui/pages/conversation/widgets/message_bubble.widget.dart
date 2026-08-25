import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final message = entry.message;
    final outgoing = message.isOutgoing;
    final failed = message.status.hasFailed;

    final background = outgoing ? colors.bubbleOutgoing : colors.bubbleIncoming;
    final foreground = outgoing
        ? colors.onBubbleOutgoing
        : colors.onBubbleIncoming;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        entry.isFirstOfGroup ? 6 : 1,
        16,
        entry.isLastOfGroup ? 2 : 1,
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
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: failed ? colors.surfaceAlt : background,
                      borderRadius: _radius(outgoing),
                      border: failed
                          ? Border.all(color: colors.danger, width: 1)
                          : null,
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: failed ? colors.textPrimary : foreground,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (entry.showStatus || failed)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                message.statusLabel,
                key: Key('status_${message.id}'),
                style: TextStyle(
                  fontSize: 11,
                  color: failed ? colors.danger : colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
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
