import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/theme/app_theme_data.dart';

/// Un groupe de lignes réunies dans une carte arrondie, séparées par un filet.
///
/// C'est la forme que prennent les réglages et le menu du compte dans Google
/// Messages : plusieurs cartes empilées sur le fond pêche, chacune tenant un
/// petit paquet de lignes qui vont ensemble.
class CardGroup extends StatelessWidget {
  const CardGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
  });

  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: margin,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppThemeData.cardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: colors.outlineVariant),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne de [CardGroup] : icône contour à gauche, libellé, et de quoi
/// agir à droite.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 24, color: iconColor ?? colors.textPrimary),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(color: colors.textMuted, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Intertitre au-dessus d'un groupe de cartes — « Plus de contenus de cette
/// appli » dans l'app d'origine.
class CardGroupHeader extends StatelessWidget {
  const CardGroupHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Text(
        label,
        style: TextStyle(color: colors.textMuted, fontSize: 15),
      ),
    );
  }
}
