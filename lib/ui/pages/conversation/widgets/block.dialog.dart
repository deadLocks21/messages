import 'package:flutter/material.dart';

/// « Bloquer ce numéro ? », mot pour mot ce qu'annonce l'app d'origine —
/// moins « signaler comme spam ».
///
/// La case à cocher de Google envoie le numéro et les derniers messages à
/// Google et aux opérateurs. Ce service n'existe que chez eux ; une case qui
/// promettrait la même chose sans rien envoyer serait pire que son absence.
abstract final class BlockDialog {
  static Future<bool?> confirm(BuildContext context, String name) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Bloquer $name ?'),
          content: const Text(
            'Vous ne recevrez plus ni appels ni messages de ce numéro. La '
            'conversation restera dans « Spam et bloqués », sans notification.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              key: const Key('confirmBlock'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bloquer'),
            ),
          ],
        ),
      );
}
