import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/utils/date_format.dart';

/// Un message trouvé : le fil dont il vient, l'extrait avec le terme surligné,
/// et sa date.
class MessageHitTile extends StatelessWidget {
  const MessageHitTile({
    super.key,
    required this.hit,
    required this.query,
    required this.onTap,
    this.now,
  });

  final MessageHitDto hit;
  final String query;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      key: Key('messageHit_${hit.message.id}'),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Row(
        children: [
          Expanded(
            child: Text(
              hit.conversationTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            MessagesDateFormat.conversationStamp(hit.message.sentAt, now: now),
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ],
      ),
      subtitle: Text.rich(
        _highlight(hit.message.body, query, colors),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Met en évidence l'occurrence trouvée, sans dépendance à une lib de
  /// surlignage : une simple découpe en trois morceaux suffit.
  TextSpan _highlight(String body, String query, AppColors colors) {
    final index = body.toLowerCase().indexOf(query.toLowerCase());
    final base = TextStyle(color: colors.textMuted, fontSize: 15, height: 1.3);
    if (index < 0) return TextSpan(text: body, style: base);

    return TextSpan(
      style: base,
      children: [
        TextSpan(text: body.substring(0, index)),
        TextSpan(
          text: body.substring(index, index + query.length),
          style: base.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: body.substring(index + query.length)),
      ],
    );
  }
}
