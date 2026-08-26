import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/theme/app_theme_data.dart';

/// Le panneau blanc cassé posé sur le fond pêche, coins hauts arrondis.
///
/// C'est la mise en page de Google Messages : les barres et le fond d'écran
/// restent dans la teinte du thème, et tout le contenu (liste des fils, fil de
/// discussion) vit dans ce panneau qui vient s'y encastrer.
class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key, required this.child, this.color});

  final Widget child;

  /// Par défaut `AppColors.surface`. Le fil de discussion s'en sert pour poser
  /// un ton légèrement différent de celui de la liste.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: color ?? colors.surface,
      // `antiAlias` suffit : le contenu défile sous les coins, il faut qu'ils
      // le rognent proprement.
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppThemeData.panelRadius),
      ),
      child: child,
    );
  }
}
