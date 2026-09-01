import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/ui/pages/conversation/widgets/message_bubble.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/reaction_bar.widget.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/utils/date_format.dart';

/// Ce qu'on peut faire d'un message : appui long dans le fil.
enum MessageAction { copy, forward, delete, resend, details }

/// Ce que la feuille rend : une action, ou un emoji.
///
/// Deux formes plutôt qu'une action de plus, parce qu'une réaction porte une
/// donnée que les autres n'ont pas — l'emoji choisi.
sealed class MessageChoice {
  const MessageChoice();
}

class MessageActionChoice extends MessageChoice {
  final MessageAction action;
  const MessageActionChoice(this.action);
}

class MessageReactionChoice extends MessageChoice {
  final String emoji;
  const MessageReactionChoice(this.emoji);
}

/// Les actions d'un message, **ancrées sur sa bulle**.
///
/// C'est la mise en page de l'app d'origine, et elle dit quelque chose qu'une
/// feuille du bas ne disait pas : *de quel message on parle*. Le fil s'assombrit,
/// la bulle visée reste éclairée à sa place, la rangée d'emoji se pose au-dessus
/// et le menu en dessous. Une feuille ancrée en bas de l'écran obligeait à
/// retenir sur quoi on venait d'appuyer.
///
/// La bulle est **redessinée** dans la surcouche plutôt que découpée de l'écran :
/// [MessageBubble] est une fonction de son entrée, la repeindre à la même
/// largeur la redonne au pixel près, sans capture d'image ni couche de rendu
/// supplémentaire.
abstract final class MessageActionsOverlay {
  /// Écart entre la bulle et ce qui l'encadre, relevé sur l'app d'origine.
  static const _gapAbove = 8.0;
  static const _gapBelow = 4.0;

  /// Marge latérale de la pilule d'emoji : elle va presque d'un bord à l'autre.
  static const _barMargin = 13.0;

  static const _barHeight = 56.0;

  /// Largeur du menu, et hauteur d'une de ses lignes.
  static const _menuWidth = 208.0;
  static const _menuRow = 48.0;

  /// Le menu s'aligne sur le bord de la bulle, donc sur la marge du fil.
  static const _bubbleMargin = 14.0;

  /// Durée relevée sur l'app d'origine, image par image : les deux panneaux y
  /// sont posés en une quinzaine d'images à 60 Hz.
  static const _grow = Duration(milliseconds: 250);

  /// Une décélération franche, mais pas instantanée. Relevée sur l'app
  /// d'origine : le panneau passe six images à grandir avant de se poser, et
  /// c'est cette phase-là qui le fait lire comme un dépliement. Une courbe plus
  /// chargée à l'avant (l'« emphasized » de Material) la saute entièrement — le
  /// panneau naît large, et il ne reste qu'un fondu.
  static const _ease = Curves.easeOutCubic;

  /// De quelle taille les panneaux partent. Pas de zéro : un panneau qui naît
  /// d'un point se lit comme un surgissement, alors qu'il se déplie.
  static const _from = 0.3;

  static Future<MessageChoice?> show(
    BuildContext context, {
    required TimelineMessage entry,
    required Rect anchor,
  }) {
    return showGeneralDialog<MessageChoice>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: _grow,
      // Chaque bloc a sa propre entrée — une transition d'ensemble les ferait
      // tous grandir depuis le même point, et le menu se décollerait de la
      // bulle qu'il commande.
      pageBuilder: (context, animation, _) =>
          _ActionsLayer(entry: entry, anchor: anchor, animation: animation),
    );
  }

  /// Fiche « Détails du message » : type, interlocuteur, date, état.
  static Future<void> showDetails(BuildContext context, MessageDto message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('messageDetails'),
        title: const Text('Détails du message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailLine(label: 'Type', value: 'SMS'),
            _DetailLine(
              label: message.isOutgoing ? 'À' : 'De',
              value: message.address,
            ),
            _DetailLine(
              label: message.isOutgoing ? 'Envoyé' : 'Reçu',
              value: MessagesDateFormat.full(message.sentAt),
            ),
            _DetailLine(label: 'État', value: message.statusLabel),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Copie le corps du message dans le presse-papiers.
  static Future<void> copy(MessageDto message) =>
      Clipboard.setData(ClipboardData(text: message.body));
}

/// La surcouche elle-même : bulle repeinte, pilule au-dessus, menu en dessous.
class _ActionsLayer extends StatelessWidget {
  const _ActionsLayer({
    required this.entry,
    required this.anchor,
    required this.animation,
  });

  final TimelineMessage entry;
  final Rect anchor;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final actions = _actionsFor(message);

    final media = MediaQuery.of(context);
    final menuHeight = actions.length * MessageActionsOverlay._menuRow;

    // Les trois blocs bougent ensemble : décaler la bulle sans son menu la
    // décrocherait de ce qu'elle commande.
    final wanted =
        anchor.top -
        MessageActionsOverlay._gapAbove -
        MessageActionsOverlay._barHeight;
    final bottom =
        anchor.bottom + MessageActionsOverlay._gapBelow + menuHeight;

    final topLimit = media.padding.top + 8;
    final bottomLimit = media.size.height - media.padding.bottom - 8;

    var shift = 0.0;
    if (bottom > bottomLimit) shift = bottomLimit - bottom;
    if (wanted + shift < topLimit) shift = topLimit - wanted;

    final barTop = wanted + shift;
    final bubbleTop = anchor.top + shift;
    final menuTop =
        anchor.bottom + shift + MessageActionsOverlay._gapBelow;

    // La pilule se déplie depuis son centre, le menu depuis le coin qui touche
    // la bulle : c'est de là qu'ils sortent dans l'app d'origine, et c'est ce
    // qui les rattache visuellement au message.
    final grow = Tween<double>(
      begin: MessageActionsOverlay._from,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: MessageActionsOverlay._ease,
      ),
    );
    // Le fondu va plus vite que la taille : sans cela, on verrait une forme
    // pâle grandir au lieu d'un panneau qui se pose.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.25, curve: Curves.easeOut),
    );

    return Stack(
      children: [
        // Le fond entier renvoie l'appui : hors de la bulle et de ses deux
        // panneaux, on ferme.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          top: barTop,
          left: MessageActionsOverlay._barMargin,
          right: MessageActionsOverlay._barMargin,
          child: FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: grow,
              child: ReactionBar(
                message: message,
                onPick: (emoji) =>
                    Navigator.of(context).pop(MessageReactionChoice(emoji)),
              ),
            ),
          ),
        ),
        Positioned(
          top: bubbleTop,
          left: 0,
          right: 0,
          // La copie est inerte : c'est un rappel de ce qu'on vise, pas une
          // seconde bulle sur laquelle agir.
          // Transparente, mais indispensable : les pastilles de la bulle sont
          // des `InkWell`, qui exigent une surface même inertes.
          // La bulle ne grandit pas : elle est déjà à l'écran, elle ne fait que
          // passer au-dessus du voile.
          child: FadeTransition(
            opacity: fade,
            child: Material(
              type: MaterialType.transparency,
              child: IgnorePointer(
                child: MessageBubble(
                  entry: entry,
                  onLongPress: (_) {},
                  onReactionsTap: () {},
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: menuTop,
          left: message.isOutgoing
              ? null
              : MessageActionsOverlay._bubbleMargin,
          right: message.isOutgoing
              ? MessageActionsOverlay._bubbleMargin
              : null,
          child: FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: grow,
              alignment: message.isOutgoing
                  ? Alignment.topRight
                  : Alignment.topLeft,
              child: _ActionsMenu(actions: actions),
            ),
          ),
        ),
      ],
    );
  }

  List<_ActionItem> _actionsFor(MessageDto message) => [
    if (message.status.hasFailed)
      const _ActionItem(
        key: 'messageActionResend',
        icon: Icons.refresh,
        label: 'Réessayer',
        action: MessageAction.resend,
      ),
    const _ActionItem(
      key: 'messageActionCopy',
      icon: Icons.content_copy_outlined,
      label: 'Copier',
      action: MessageAction.copy,
    ),
    const _ActionItem(
      key: 'messageActionForward',
      icon: Icons.forward_outlined,
      label: 'Transférer',
      action: MessageAction.forward,
    ),
    const _ActionItem(
      key: 'messageActionDelete',
      icon: Icons.delete_outline,
      label: 'Supprimer',
      action: MessageAction.delete,
    ),
    const _ActionItem(
      key: 'messageActionDetails',
      icon: Icons.info_outline,
      label: 'Afficher les détails',
      action: MessageAction.details,
    ),
  ];
}

class _ActionItem {
  final String key;
  final IconData icon;
  final String label;
  final MessageAction action;

  const _ActionItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.action,
  });
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.actions});

  final List<_ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      child: SizedBox(
        width: MessageActionsOverlay._menuWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in actions)
              InkWell(
                key: Key(item.key),
                onTap: () => Navigator.of(
                  context,
                ).pop(MessageActionChoice(item.action)),
                child: SizedBox(
                  height: MessageActionsOverlay._menuRow,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(item.icon, size: 22, color: colors.textPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
