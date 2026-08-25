import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/utils/date_format.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';

/// Une ligne de la liste des conversations.
///
/// Non lu ⇒ nom et aperçu en gras, horodatage à la couleur d'accent : c'est la
/// seule marque que Google Messages utilise, sans pastille de compteur.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.now,
  });

  final ConversationDto conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// Injectable pour que les tests contrôlent les libellés d'horodatage.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final unread = conversation.hasUnread;

    return InkWell(
      key: Key('conversationTile_${conversation.threadId}'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? colors.accentSoft.withValues(alpha: 0.6) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            selected
                ? CircleAvatar(
                    radius: 24,
                    backgroundColor: colors.accent,
                    child: Icon(Icons.check, color: colors.onAccent),
                  )
                : Avatar(avatar: conversation.avatar),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.textPrimary,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        MessagesDateFormat.conversationStamp(
                          conversation.lastMessageAt,
                          now: now,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: unread ? colors.accent : colors.textMuted,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(child: _Snippet(conversation: conversation)),
                      if (conversation.isMuted) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 16,
                          color: colors.textMuted,
                        ),
                      ],
                      if (conversation.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin, size: 16, color: colors.textMuted),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu du fil : le brouillon l'emporte sur le dernier message, comme dans
/// Google Messages, et se signale par un préfixe rouge.
class _Snippet extends StatelessWidget {
  const _Snippet({required this.conversation});

  final ConversationDto conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final unread = conversation.hasUnread;
    final style = TextStyle(
      fontSize: 14,
      color: unread ? colors.textPrimary : colors.textMuted,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );

    if (conversation.hasDraft) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Brouillon : ',
              style: style.copyWith(color: colors.danger),
            ),
            TextSpan(text: conversation.draft!.trim()),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return Text(
      conversation.snippet,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
