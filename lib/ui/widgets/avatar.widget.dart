import 'package:flutter/material.dart';
import 'package:messages/core/application/dtos/avatar.dto.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Pastille d'interlocuteur : la photo du carnet d'adresses si elle existe,
/// sinon l'initiale sur fond coloré — et une icône générique quand il n'y a
/// même pas d'initiale (numéro inconnu, numéro court).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.avatar, this.size = 48});

  final AvatarDto avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.avatarColor(avatar.colorSlot);

    if (avatar.hasPhoto) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: MemoryImage(avatar.photo!),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: avatar.isGroup
          ? Icon(Icons.group, color: Colors.white, size: size * 0.5)
          : avatar.initial.isEmpty
          ? Icon(Icons.person, color: Colors.white, size: size * 0.55)
          : Text(
              avatar.initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}
