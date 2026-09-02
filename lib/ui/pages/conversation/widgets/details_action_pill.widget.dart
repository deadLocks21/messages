import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Un bouton rond de l'écran de détails : la pastille, et son libellé dessous.
///
/// Deux couleurs, et elles ne viennent pas de la même palette — c'est le
/// relevé de l'app d'origine :
///
/// - la pastille est le `secondaryContainer` ([AppColors.panel]), celui du
///   panneau d'enregistrement — #DFE0FF en clair, #2E3AA1 en sombre, avec son
///   icône en [AppColors.onPanel] ;
/// - le **libellé**, lui, est posé sur le fond et non dans la pastille : il
///   prend le neutre du texte courant, pas l'`on` de la pastille. En thème
///   sombre les deux tombent sur la même valeur, en clair non — #13183D sous
///   une icône #000965.
class DetailsActionPill extends StatelessWidget {
  const DetailsActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: colors.panel,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Icon(icon, size: 24, color: colors.onPanel),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
      ],
    );
  }
}
