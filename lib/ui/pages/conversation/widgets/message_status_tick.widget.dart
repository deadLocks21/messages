import 'package:flutter/material.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// L'état d'un envoi, dit par une coche plutôt que par un mot.
///
/// Une coche : le réseau a pris le message. Deux : le téléphone d'en face l'a
/// reçu. Il n'y en a pas de troisième — le SMS ne rapporte pas la lecture, et
/// une coche bleue à la WhatsApp affirmerait ici ce que personne ne sait.
///
/// L'**échec garde ses mots**, et il est le seul. Une coche se lit d'un coup
/// d'œil parce qu'on sait déjà que le message est parti : elle n'a qu'à dire
/// jusqu'où. Un point d'exclamation, lui, annonce un problème sans dire lequel,
/// et c'est justement le moment où l'utilisateur a besoin qu'on le lui dise.
///
/// Partout ailleurs l'icône ne remplace le libellé qu'à l'œil : `Semantics` le
/// rend au lecteur d'écran, à qui deux traits ne disent rien.
class MessageStatusTick extends StatelessWidget {
  const MessageStatusTick({
    super.key,
    required this.status,
    required this.label,
  });

  final MessageStatus status;
  final String label;

  /// Calé sur le texte qu'il remplace (12 px) : une icône se lit un peu plus
  /// petit que sa boîte, d'où les 15.
  static const _size = 15.0;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      MessageStatus.sending => Icons.schedule,
      MessageStatus.sent => Icons.check,
      MessageStatus.delivered => Icons.done_all,
      MessageStatus.failed => Icons.error_outline,
      // Un entrant ne porte pas d'état : c'est déjà d'être là qui le dit.
      MessageStatus.received => null,
    };
    if (icon == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final failed = status.hasFailed;
    final color = failed ? colors.danger : colors.textMuted;
    final tick = Icon(icon, size: _size, color: color);

    if (!failed) return Semantics(label: label, child: tick);

    // Le libellé est déjà là pour l'œil : `MergeSemantics` en fait une seule
    // annonce, plutôt qu'une icône et un texte qui répètent la même chose.
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tick,
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
