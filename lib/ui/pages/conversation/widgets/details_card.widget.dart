import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/conversation_details.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';

/// Rayon relevé sur l'app d'origine — 29 px à 2,625 px/dp.
const double _radius = 12;

/// Marge latérale des cartes, la même que celle des boutons ronds.
const double _sideMargin = 16;

/// Une carte de l'écran de détails.
///
/// Elle ne ressemble pas à celles des réglages (`CardGroup`) : là-bas
/// plusieurs lignes partagent une carte et se séparent d'un filet ; ici
/// **chaque ligne est sa propre carte**, à 2 de la suivante. Le filet
/// disparaît, l'écart le remplace — c'est ce que fait l'app d'origine, et
/// c'est ce qui permet à la ligne rouge du bas de se détacher sans bordure.
class DetailsCard extends StatelessWidget {
  const DetailsCard({super.key, required this.child, this.margin});

  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          margin ??
          const EdgeInsets.only(
            left: _sideMargin,
            right: _sideMargin,
            bottom: 2,
          ),
      child: Material(
        color: context.appColors.card,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(_radius),
        child: child,
      ),
    );
  }
}

/// Une ligne de réglage : icône, libellé, et rien d'autre.
class DetailsCardRow extends StatelessWidget {
  const DetailsCardRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Teinte de l'icône *et* du libellé — la ligne rouge de l'app d'origine les
  /// peint tous deux.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = color ?? colors.textPrimary;

    return DetailsCard(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: _sideMargin),
              Icon(icon, size: 24, color: foreground),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground, fontSize: 16),
                ),
              ),
              const SizedBox(width: _sideMargin),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'intertitre d'une carte — « 1 autre personne ».
class DetailsCardHeader extends StatelessWidget {
  const DetailsCardHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: _sideMargin),
          Text(
            label,
            style: TextStyle(
              color: context.appColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une personne du fil : pastille, nom, numéro.
class DetailsMemberRow extends StatelessWidget {
  const DetailsMemberRow({
    super.key,
    required this.participant,
    required this.onTap,
  });

  final ParticipantDto participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            const SizedBox(width: _sideMargin),
            Avatar(avatar: participant.avatar, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  ),
                  if (participant.addressLabel.isNotEmpty)
                    Text(
                      participant.addressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(width: _sideMargin),
          ],
        ),
      ),
    );
  }
}
