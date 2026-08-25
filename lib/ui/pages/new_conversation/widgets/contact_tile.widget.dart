import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/contact.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';

/// Une proposition du sélecteur de destinataires.
class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact, required this.onTap});

  final ContactDto contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
      key: Key('contactTile_${contact.id}'),
      onTap: onTap,
      leading: Avatar(avatar: contact.avatar, size: 40),
      title: Text(contact.displayName),
      subtitle: contact.primaryAddressLabel == contact.displayName
          ? null
          : Text(
              contact.primaryAddressLabel,
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
    );
  }
}
