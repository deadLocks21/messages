import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Les pastilles de réaction accrochées au bas d'une bulle.
///
/// Elles mordent sur la bulle (`_overlap`) comme dans l'app d'origine : posées
/// en dessous, elles se liraient comme un message de plus — et c'est justement
/// ce qu'on cherche à ne plus montrer.
class ReactionChips extends StatelessWidget {
  const ReactionChips({
    super.key,
    required this.message,
    required this.onTap,
  });

  final MessageDto message;

  /// Un appui rouvre la feuille : c'est de là qu'on change ou retire sa
  /// réaction.
  final VoidCallback onTap;

  /// De combien la rangée remonte sur la bulle.
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    return Transform.translate(
      offset: const Offset(0, -_overlap),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Wrap(
          spacing: 4,
          children: [
            for (final reaction in message.reactions)
              Semantics(
                button: true,
                label: reaction.label,
                child: InkWell(
                  key: Key('reaction_${message.id}_${reaction.emoji}'),
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        // La sienne se souligne : sur un fil de groupe, c'est
                        // la seule façon de savoir si l'on a déjà réagi.
                        color: reaction.isMine
                            ? colors.accent
                            : colors.outlineVariant,
                        width: reaction.isMine ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reaction.emoji,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (reaction.count > 1) ...[
                          const SizedBox(width: 3),
                          Text(
                            '${reaction.count}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
