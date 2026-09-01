import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/dtos/reaction.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';

/// La fiche « Réactions » : qui a posé quoi sur un message.
///
/// Elle liste des **personnes**, pas des emoji. C'est le choix de l'app
/// d'origine, et il se défend : la pastille dit déjà combien de pouces il y a,
/// la seule chose qu'elle ne peut pas dire est de qui ils viennent. Regrouper
/// à nouveau par emoji ici ne ferait que répéter la pastille.
///
/// Elle ne fait rien d'autre que montrer — les lignes ne sont pas cliquables,
/// comme dans l'app d'origine. Retirer sa réaction reste un appui long sur la
/// bulle : c'est là qu'est la barre d'emoji, et un appui distrait sur son
/// propre nom ne doit pas effacer ce qu'on venait vérifier.
abstract final class ReactionsSheet {
  static Future<void> show(BuildContext context, MessageDto message) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => _ReactionsList(authors: message.reactionAuthors),
    );
  }
}

/// La pastille « Vous » : celle du compte, reprise de la barre du haut — le
/// seul visage que l'app se connaisse.
class _MyAvatar extends StatelessWidget {
  const _MyAvatar({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.accentSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 22, color: colors.onAccentSoft),
    );
  }
}

class _ReactionsList extends StatelessWidget {
  const _ReactionsList({required this.authors});

  final List<ReactionAuthorDto> authors;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: Column(
        key: const Key('reactionsSheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 18),
            child: Text(
              'Réactions',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
          for (final author in authors)
            Semantics(
              label: author.label,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      if (author.avatar case final avatar?)
                        Avatar(avatar: avatar, size: 40)
                      else
                        _MyAvatar(colors: colors),
                      // 72 px du bord au nom : la même colonne que les autres
                      // listes de l'app, pour que les pastilles s'alignent
                      // d'un écran à l'autre.
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          author.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        author.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
