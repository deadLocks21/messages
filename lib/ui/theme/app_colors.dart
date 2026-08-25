// messages — tokens de couleur repris de Google Messages (bleu Google sur
// neutres). Pattern kidflix/motorz : palette brute + ThemeExtension `AppColors`
// + `context.appColors`.

import 'package:flutter/material.dart';

/// Palette brute (tokens bas niveau). Ne pas utiliser directement dans l'UI :
/// toujours passer par [AppColors] / `context.appColors`.
abstract final class GmPalette {
  // Bleu Google — couleur de marque, des bulles envoyées et du FAB.
  static const blue = Color(0xFF0B57D0); // primary (clair)
  static const blueLight = Color(0xFFA8C7FA); // primary (sombre)
  static const blueContainer = Color(0xFFD3E3FD); // container (clair)
  static const onBlueContainer = Color(0xFF041E49);
  static const blueContainerDark = Color(0xFF0842A0); // container (sombre)
  static const onBlueContainerDark = Color(0xFFD3E3FD);

  // Neutres clairs
  static const white = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF0F4F9); // barre de recherche, champs
  static const bubbleInLight = Color(0xFFE9EEF6); // bulle reçue
  static const onBubbleInLight = Color(0xFF1F1F1F);
  static const inkLight = Color(0xFF1F1F1F);
  static const mutedLight = Color(0xFF5F6368);
  static const outlineLight = Color(0xFFE1E3E1);

  // Neutres sombres
  static const surfaceDark = Color(0xFF131314); // fond
  static const surfaceAltDark = Color(0xFF1E1F20); // barre de recherche, champs
  static const bubbleInDark = Color(0xFF2D2F31); // bulle reçue
  static const onBubbleInDark = Color(0xFFE3E3E3);
  static const inkDark = Color(0xFFE3E3E3);
  static const mutedDark = Color(0xFF9AA0A6);
  static const outlineDark = Color(0xFF444746);

  // Bulle envoyée : bleu plein en clair, bleu pâle sur texte sombre en sombre —
  // c'est l'inversion que fait Google Messages.
  static const bubbleOutLight = blue;
  static const onBubbleOutLight = white;
  static const bubbleOutDark = blueLight;
  static const onBubbleOutDark = Color(0xFF062E6F);

  static const error = Color(0xFFD93025);

  /// Couleurs d'avatar, dans l'ordre des créneaux rendus par
  /// `AvatarPaletteService.slotFor` (8 créneaux, initiale toujours blanche).
  static const avatarSlots = <Color>[
    Color(0xFF4285F4), // bleu
    Color(0xFFEA4335), // rouge
    Color(0xFFF9AB00), // jaune
    Color(0xFF34A853), // vert
    Color(0xFFA142F4), // violet
    Color(0xFF24C1E0), // cyan
    Color(0xFFFA7B17), // orange
    Color(0xFFF439A0), // rose
  ];
}

/// Tokens sémantiques exposés à l'UI via `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.bubbleIncoming,
    required this.onBubbleIncoming,
    required this.bubbleOutgoing,
    required this.onBubbleOutgoing,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt; // barre de recherche, champ de saisie, puces
  final Color outline;
  final Color textPrimary;
  final Color textMuted;
  final Color accent; // bleu Google — FAB, envoi, sélection
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color bubbleIncoming;
  final Color onBubbleIncoming;
  final Color bubbleOutgoing;
  final Color onBubbleOutgoing;
  final Color danger; // échec d'envoi, suppression

  /// Couleur de la pastille d'avatar pour un créneau donné.
  static Color avatarColor(int slot) =>
      GmPalette.avatarSlots[slot % GmPalette.avatarSlots.length];

  static const AppColors light = AppColors(
    background: GmPalette.white,
    surface: GmPalette.surfaceLight,
    surfaceAlt: GmPalette.surfaceAltLight,
    outline: GmPalette.outlineLight,
    textPrimary: GmPalette.inkLight,
    textMuted: GmPalette.mutedLight,
    accent: GmPalette.blue,
    onAccent: GmPalette.white,
    accentSoft: GmPalette.blueContainer,
    onAccentSoft: GmPalette.onBlueContainer,
    bubbleIncoming: GmPalette.bubbleInLight,
    onBubbleIncoming: GmPalette.onBubbleInLight,
    bubbleOutgoing: GmPalette.bubbleOutLight,
    onBubbleOutgoing: GmPalette.onBubbleOutLight,
    danger: GmPalette.error,
  );

  static const AppColors dark = AppColors(
    background: GmPalette.surfaceDark,
    surface: GmPalette.surfaceDark,
    surfaceAlt: GmPalette.surfaceAltDark,
    outline: GmPalette.outlineDark,
    textPrimary: GmPalette.inkDark,
    textMuted: GmPalette.mutedDark,
    accent: GmPalette.blueLight,
    onAccent: GmPalette.onBubbleOutDark,
    accentSoft: GmPalette.blueContainerDark,
    onAccentSoft: GmPalette.onBlueContainerDark,
    bubbleIncoming: GmPalette.bubbleInDark,
    onBubbleIncoming: GmPalette.onBubbleInDark,
    bubbleOutgoing: GmPalette.bubbleOutDark,
    onBubbleOutgoing: GmPalette.onBubbleOutDark,
    danger: GmPalette.error,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? textPrimary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? bubbleIncoming,
    Color? onBubbleIncoming,
    Color? bubbleOutgoing,
    Color? onBubbleOutgoing,
    Color? danger,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      bubbleIncoming: bubbleIncoming ?? this.bubbleIncoming,
      onBubbleIncoming: onBubbleIncoming ?? this.onBubbleIncoming,
      bubbleOutgoing: bubbleOutgoing ?? this.bubbleOutgoing,
      onBubbleOutgoing: onBubbleOutgoing ?? this.onBubbleOutgoing,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      bubbleIncoming: Color.lerp(bubbleIncoming, other.bubbleIncoming, t)!,
      onBubbleIncoming: Color.lerp(onBubbleIncoming, other.onBubbleIncoming, t)!,
      bubbleOutgoing: Color.lerp(bubbleOutgoing, other.bubbleOutgoing, t)!,
      onBubbleOutgoing: Color.lerp(onBubbleOutgoing, other.onBubbleOutgoing, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Raccourci d'accès : `context.appColors.accent`.
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// Schémas Material 3 — bleu Google en `primary`.
final ColorScheme messagesLightScheme = ColorScheme.fromSeed(
  seedColor: GmPalette.blue,
  brightness: Brightness.light,
).copyWith(
  primary: GmPalette.blue,
  onPrimary: GmPalette.white,
  primaryContainer: GmPalette.blueContainer,
  onPrimaryContainer: GmPalette.onBlueContainer,
  surface: GmPalette.surfaceLight,
  onSurface: GmPalette.inkLight,
  surfaceContainerHighest: GmPalette.surfaceAltLight,
  outline: GmPalette.outlineLight,
  error: GmPalette.error,
);

final ColorScheme messagesDarkScheme = ColorScheme.fromSeed(
  seedColor: GmPalette.blue,
  brightness: Brightness.dark,
).copyWith(
  primary: GmPalette.blueLight,
  onPrimary: GmPalette.onBubbleOutDark,
  primaryContainer: GmPalette.blueContainerDark,
  onPrimaryContainer: GmPalette.onBlueContainerDark,
  surface: GmPalette.surfaceDark,
  onSurface: GmPalette.inkDark,
  surfaceContainerHighest: GmPalette.surfaceAltDark,
  outline: GmPalette.outlineDark,
  error: GmPalette.error,
);
