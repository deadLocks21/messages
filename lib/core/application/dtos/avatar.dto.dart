import 'dart:typed_data';

/// De quoi peindre un avatar sans que l'UI ait à connaître les contacts :
/// une vignette si le carnet en fournit une, sinon une initiale sur une
/// pastille dont la couleur est stable pour un interlocuteur donné.
class AvatarDto {
  /// Lettre affichée à défaut de photo. Vide ⇒ icône générique.
  final String initial;

  /// Index dans la palette d'avatars (`AvatarPaletteService.slots`). Stable
  /// pour un même interlocuteur d'une session à l'autre.
  final int colorSlot;

  final Uint8List? photo;

  /// Conversation de groupe : l'UI empile deux pastilles.
  final bool isGroup;

  const AvatarDto({
    required this.initial,
    required this.colorSlot,
    this.photo,
    this.isGroup = false,
  });

  bool get hasPhoto => photo != null && photo!.isNotEmpty;
}
