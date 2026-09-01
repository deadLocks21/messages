import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/ui/pages/conversation/widgets/reaction_bar.widget.dart';
import 'package:messages/ui/utils/date_format.dart';

/// Ce qu'on peut faire d'un message : appui long dans le fil.
enum MessageAction { copy, forward, delete, resend }

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

/// Feuille d'actions d'un message, plus la fiche « Détails ».
abstract final class MessageOptionsSheet {
  static Future<MessageChoice?> show(
    BuildContext context,
    MessageDto message,
  ) {
    return showModalBottomSheet<MessageChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En tête, comme dans l'app d'origine : réagir est le geste le plus
            // fréquent, et le seul qu'on vient rarement chercher dans une
            // liste.
            ReactionBar(
              message: message,
              onPick: (emoji) =>
                  Navigator.of(context).pop(MessageReactionChoice(emoji)),
            ),
            const Divider(height: 1),
            if (message.status.hasFailed)
              ListTile(
                key: const Key('messageActionResend'),
                leading: const Icon(Icons.refresh),
                title: const Text('Réessayer'),
                onTap: () => Navigator.of(
                  context,
                ).pop(const MessageActionChoice(MessageAction.resend)),
              ),
            ListTile(
              key: const Key('messageActionCopy'),
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copier'),
              onTap: () => Navigator.of(
                  context,
                ).pop(const MessageActionChoice(MessageAction.copy)),
            ),
            ListTile(
              key: const Key('messageActionForward'),
              leading: const Icon(Icons.forward_outlined),
              title: const Text('Transférer'),
              onTap: () => Navigator.of(
                  context,
                ).pop(const MessageActionChoice(MessageAction.forward)),
            ),
            ListTile(
              key: const Key('messageActionDelete'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('Supprimer'),
              onTap: () => Navigator.of(
                  context,
                ).pop(const MessageActionChoice(MessageAction.delete)),
            ),
            ListTile(
              key: const Key('messageActionDetails'),
              leading: const Icon(Icons.info_outline),
              title: const Text('Afficher les détails'),
              onTap: () {
                Navigator.of(context).pop();
                showDetails(context, message);
              },
            ),
          ],
        ),
      ),
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
