import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Ce qu'un utilisateur a choisi : une durée, ou `null` pour « Toujours ».
///
/// Un enregistrement plutôt qu'une `Duration?` nue, sinon « Toujours » et
/// « Annuler » rendraient tous les deux `null` et l'appelant ne saurait pas
/// s'il doit mettre le fil en veille ou ne rien faire.
typedef SnoozeChoice = ({Duration? duration});

/// « Mettre en veille » : quatre durées, un bouton pour valider.
///
/// Les quatre durées sont celles de l'app d'origine — une heure, huit heures,
/// vingt-quatre heures, toujours — et « huit heures » y est présélectionné.
/// « Toujours » n'est pas une durée : c'est la sourdine, et c'est bien elle
/// qu'on pose.
class SnoozeDialog extends StatefulWidget {
  const SnoozeDialog({super.key, this.initial = const Duration(hours: 8)});

  final Duration? initial;

  /// Rend `null` si l'utilisateur a renoncé.
  static Future<SnoozeChoice?> show(BuildContext context) =>
      showDialog<SnoozeChoice>(
        context: context,
        builder: (context) => const SnoozeDialog(),
      );

  @override
  State<SnoozeDialog> createState() => _SnoozeDialogState();
}

class _SnoozeDialogState extends State<SnoozeDialog> {
  static const _options = <(String, Duration?)>[
    ('1 heure', Duration(hours: 1)),
    ('8 heures', Duration(hours: 8)),
    ('24 heures', Duration(hours: 24)),
    ('Toujours', null),
  ];

  late Duration? _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      title: const Text('Mettre en veille'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      // `null` vaut « Toujours » et non « rien de coché » : la liste part
      // toujours d'un choix, comme celle de l'app d'origine.
      content: RadioGroup<Duration?>(
        groupValue: _selected,
        onChanged: (value) => setState(() => _selected = value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, duration) in _options)
              RadioListTile<Duration?>(
                key: Key('snooze_${duration?.inHours ?? 'always'}'),
                value: duration,
                title: Text(label, style: TextStyle(color: colors.textPrimary)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          key: const Key('confirmSnooze'),
          onPressed: () =>
              Navigator.of(context).pop((duration: _selected)),
          child: const Text('Mettre en veille'),
        ),
      ],
    );
  }
}
