import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/contact.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';

/// Une proposition du sélecteur de destinataires : une carte arrondie posée
/// sur le fond pêche, comme les contacts de l'écran « Nouveau chat » de Google
/// Messages.
class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact, required this.onTap});

  final ContactDto contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Un numéro brut n'a rien à répéter sous son propre nom.
    final subtitle = contact.primaryAddressLabel == contact.displayName
        ? null
        : contact.primaryAddressLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('contactTile_${contact.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
            child: Row(
              children: [
                Avatar(avatar: contact.avatar, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
