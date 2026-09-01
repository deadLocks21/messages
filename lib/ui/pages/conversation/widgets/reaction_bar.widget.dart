import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// La rangée d'emoji en tête de la feuille d'un message : ce avec quoi on
/// réagit.
///
/// Sept emoji, ceux de Google Messages, et pas un de plus. Ce n'est pas une
/// limite d'écran : cinq d'entre eux ont un **tapback iOS** équivalent, donc
/// une phrase (`Liked “…”`) dont on sait qu'elle est décodée à l'arrivée. Un
/// emoji pris au clavier partirait sous la forme `Reacted 🥑 to “…”`, plus
/// récente et moins sûre — on le fera le jour où le terrain aura dit qu'elle
/// passe.
///
/// L'emoji déjà posé est marqué : le toucher à nouveau retire la réaction, ce
/// qui coûte un second SMS et se dit donc dans l'infobulle.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key, required this.message, required this.onPick});

  final MessageDto message;

  /// Rend l'emoji choisi, et `null` jamais : c'est la feuille qui se referme.
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mine = message.myReaction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final emoji in ReactionCodec.palette)
            _ReactionButton(
              emoji: emoji,
              selected: emoji == mine,
              colors: colors,
              onTap: () => onPick(emoji),
            ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? 'Retirer la réaction ${ReactionCodec.describe(emoji)}'
          : 'Réagir : ${ReactionCodec.describe(emoji)}',
      child: InkWell(
        key: Key('react_$emoji'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? colors.accentSoft : Colors.transparent,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}
