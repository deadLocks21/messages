import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/utils/date_format.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';

/// Une ligne de la liste des conversations.
///
/// Non lu ⇒ nom et aperçu appuyés, et une **pastille de compteur** ambre sous
/// l'horodatage : c'est ainsi que Google Messages marque un fil non lu.
/// L'aperçu court sur deux lignes, comme dans l'app d'origine.
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

  static const _avatarSize = 54.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final unread = conversation.hasUnread;

    return InkWell(
      key: Key('conversationTile_${conversation.threadId}'),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? colors.accentSoft : null,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            selected
                ? Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.check, color: colors.onAccent),
                  )
                : Avatar(avatar: conversation.avatar, size: _avatarSize),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      color: colors.textPrimary,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _Snippet(conversation: conversation),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Stamp(conversation: conversation, now: now),
          ],
        ),
      ),
    );
  }
}

/// Colonne de droite : l'état du fil et l'heure sur la première ligne, la
/// pastille de non-lus dessous.
///
/// Sourdine et épinglage sont là plutôt que collés à l'aperçu : ce sont des
/// métadonnées du fil, elles vont avec l'horodatage, et l'aperçu garde toute
/// sa largeur pour ses deux lignes.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.conversation, this.now});

  final ConversationDto conversation;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final unread = conversation.hasUnread;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          key: Key('threadMeta_${conversation.threadId}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conversation.isMuted) ...[
              Icon(
                Icons.notifications_off_outlined,
                size: 15,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            if (conversation.isPinned) ...[
              Icon(Icons.push_pin, size: 15, color: colors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(
              MessagesDateFormat.conversationStamp(
                conversation.lastMessageAt,
                now: now,
              ),
              style: TextStyle(
                fontSize: 13,
                color: unread ? colors.textPrimary : colors.textMuted,
                fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
        if (unread) ...[
          const SizedBox(height: 8),
          Container(
            key: Key('unreadBadge_${conversation.threadId}'),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(
              // Au-delà de 99, la pastille cesserait d'être ronde : Google
              // Messages tronque, on fait pareil.
              conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
              style: TextStyle(
                color: colors.onAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
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
      fontSize: 15,
      height: 1.3,
      color: unread ? colors.textPrimary : colors.textMuted,
      fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return Text(
      conversation.snippet,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
