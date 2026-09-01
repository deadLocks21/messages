import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// La rangée d'emoji posée au-dessus de la bulle : ce avec quoi on réagit.
///
/// Une pilule qui flotte, large comme l'écran moins ses marges, exactement
/// comme dans l'app d'origine — elle se lit d'un coup d'œil parce qu'elle ne
/// partage sa ligne avec rien.
///
/// Sept emoji, ceux de Google Messages, et pas un de plus. Ce n'est pas une
/// limite d'écran : cinq d'entre eux ont un **tapback iOS** équivalent, donc
/// une phrase (`Liked “…”`) dont on sait qu'elle est décodée à l'arrivée. Un
/// emoji pris au clavier partirait sous la forme `Reacted 🥑 to “…”`, plus
/// récente et moins sûre — on le fera le jour où le terrain aura dit qu'elle
/// passe.
///
/// L'app d'origine a un huitième bouton, un « + » qui ouvre le clavier emoji.
/// On ne l'a pas, et c'est délibéré : un emoji hors palette ne partirait que
/// sous la forme la moins sûre. La pilule répartit donc ses sept sur la même
/// largeur.
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

    // `Material` et pas un `Container` décoré : la pilule flotte hors de toute
    // feuille, et ses boutons ont besoin d'une surface pour leur encre.
    return Material(
      color: colors.surface,
      shape: const StadiumBorder(),
      elevation: 3,
      child: SizedBox(
        height: 56,
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
