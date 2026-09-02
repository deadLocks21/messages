import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/theme/app_theme_data.dart';

/// Rethème un sous-arbre aux couleurs d'un fil.
///
/// Une **graine** et non une palette enregistrée : l'app sait déjà semer ses
/// cinq palettes tonales à partir d'une teinte — c'est ce qu'elle fait quand le
/// système n'en expose aucune — et un thème de discussion n'est rien d'autre
/// que ce même semis, avec une autre teinte. Tous les tons relevés sur l'app
/// d'origine s'y appliquent sans qu'on ait à les redire.
///
/// [seed] nul ⇒ rien : le fil suit l'appareil, comme tous les autres.
class ChatTheme extends StatelessWidget {
  const ChatTheme({super.key, required this.seed, required this.child});

  final int? seed;
  final Widget child;

  /// Les teintes proposées par l'écran de thème. Huit, comme l'app d'origine,
  /// et choisies pour se distinguer les unes des autres une fois semées — ce
  /// qu'on voit d'une graine, c'est la palette entière qu'elle produit.
  static const seeds = <int>[
    0xFF0B57D0, // bleu
    0xFF3F5B7C, // acier
    0xFF00696E, // sarcelle
    0xFF6B4E9E, // violet
    0xFF4F6B3F, // olive
    0xFFA44A1E, // orange
    0xFF9B4267, // rose
    0xFFA32E2E, // brique
  ];

  @override
  Widget build(BuildContext context) {
    final value = seed;
    if (value == null) return child;

    // Des neutres teintés, sans quoi un fil « violet » ne serait qu'un fil
    // gris : le fond, les barres et les bulles reçues sont tous des neutres,
    // et c'est là que se voit un thème de discussion.
    final palettes = MessagesPalettes.seeded(
      Color(value),
      neutralChroma: 12,
      neutralVariantChroma: 16,
    );
    final theme = Theme.of(context).brightness == Brightness.dark
        ? AppThemeData.buildDarkTheme(palettes)
        : AppThemeData.buildLightTheme(palettes);
    return Theme(data: theme, child: child);
  }
}
