// messages — tokens de couleur relevés sur Google Messages : le thème
// Material You « pêche » que produit un fond d'écran chaud (ambre sur neutres
// beige). Pattern kidflix/motorz : palette brute + ThemeExtension `AppColors`
// + `context.appColors`.

import 'package:flutter/material.dart';

/// Palette brute (tokens bas niveau). Ne pas utiliser directement dans l'UI :
/// toujours passer par [AppColors] / `context.appColors`.
///
/// Les valeurs claires sont échantillonnées sur des captures de l'app
/// d'origine ; les sombres en sont le pendant Material 3 sur la même teinte.
abstract final class GmPalette {
  // Ambre — couleur de marque, des bulles envoyées, des pastilles de non-lus.
  static const amber = Color(0xFF8A5100); // primary (clair)
  static const onAmber = Color(0xFFFFFFFF);
  static const amberContainer = Color(0xFFFFDCBE); // FAB, bandeaux (clair)
  static const onAmberContainer = Color(0xFF2E1500);

  static const amberLight = Color(0xFFFFB77C); // primary (sombre)
  static const onAmberLight = Color(0xFF4C2700);
  static const amberContainerDark = Color(0xFF6D3C00);
  static const onAmberContainerDark = Color(0xFFFFDCBE);

  // Neutres chauds, clairs. Trois niveaux de surface, et c'est leur empilement
  // qui fait la mise en page de l'app d'origine : les barres et le fond
  // d'écran en `container`, le panneau de contenu en `surface`, les champs et
  // les bulles reçues en `containerHigh`.
  static const surfaceLight = Color(0xFFFFF8F3);
  static const surfaceContainerLight = Color(0xFFFCEAE0);
  static const surfaceContainerHighLight = Color(0xFFF8E5DA);
  static const inkLight = Color(0xFF221A14);
  static const mutedLight = Color(0xFF52443B);
  static const outlineLight = Color(0xFF85736A);
  static const outlineVariantLight = Color(0xFFD8C2B4);

  // Neutres chauds, sombres.
  static const surfaceDark = Color(0xFF1A120B);
  static const surfaceContainerDark = Color(0xFF271E17);
  static const surfaceContainerHighDark = Color(0xFF322921);
  static const inkDark = Color(0xFFF1DFD4);
  static const mutedDark = Color(0xFFD8C2B4);
  static const outlineDark = Color(0xFFA08C82);
  static const outlineVariantDark = Color(0xFF52443B);

  // Bulle envoyée : ambre plein sur texte blanc en clair, container ambré sur
  // texte pâle en sombre — l'inversion que fait Google Messages.
  static const bubbleOutLight = amber;
  static const onBubbleOutLight = onAmber;
  static const bubbleOutDark = amberContainerDark;
  static const onBubbleOutDark = onAmberContainerDark;

  static const errorLight = Color(0xFFBA1A1A);
  static const errorDark = Color(0xFFFFB4AB);

  /// Couleurs d'avatar, dans l'ordre des créneaux rendus par
  /// `AvatarPaletteService.slotFor` (8 créneaux, initiale toujours blanche).
  /// Relevées une à une sur les captures : ces pastilles-là ne suivent pas le
  /// thème, elles sont les mêmes quelle que soit la couleur dominante.
  static const avatarSlots = <Color>[
    Color(0xFFAC5BF2), // violet
    Color(0xFFFC63B5), // rose
    Color(0xFFEC665C), // corail
    Color(0xFF4ECCE3), // cyan
    Color(0xFFFBC735), // jaune
    Color(0xFFF98F3D), // orange
    Color(0xFF5BB874), // vert
    Color(0xFF5C93F5), // bleu
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
    required this.outlineVariant,
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

  /// Fond d'écran et barres — la teinte pêche sur laquelle tout se pose.
  final Color background;

  /// Panneau de contenu (listes, cartes) : posé sur [background], coins hauts
  /// arrondis.
  final Color surface;

  /// Champs de saisie, bulles reçues, puces.
  final Color surfaceAlt;

  final Color outline;

  /// Filets de séparation à l'intérieur d'une carte — plus discret que
  /// [outline], qui sert aux contours.
  final Color outlineVariant;

  final Color textPrimary;
  final Color textMuted;
  final Color accent; // ambre — pastille de non-lus, envoi, sélection
  final Color onAccent;
  final Color accentSoft; // FAB, bandeaux
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
    background: GmPalette.surfaceContainerLight,
    surface: GmPalette.surfaceLight,
    surfaceAlt: GmPalette.surfaceContainerHighLight,
    outline: GmPalette.outlineLight,
    outlineVariant: GmPalette.outlineVariantLight,
    textPrimary: GmPalette.inkLight,
    textMuted: GmPalette.mutedLight,
    accent: GmPalette.amber,
    onAccent: GmPalette.onAmber,
    accentSoft: GmPalette.amberContainer,
    onAccentSoft: GmPalette.onAmberContainer,
    bubbleIncoming: GmPalette.surfaceContainerHighLight,
    onBubbleIncoming: GmPalette.inkLight,
    bubbleOutgoing: GmPalette.bubbleOutLight,
    onBubbleOutgoing: GmPalette.onBubbleOutLight,
    danger: GmPalette.errorLight,
  );

  static const AppColors dark = AppColors(
    background: GmPalette.surfaceContainerDark,
    surface: GmPalette.surfaceDark,
    surfaceAlt: GmPalette.surfaceContainerHighDark,
    outline: GmPalette.outlineDark,
    outlineVariant: GmPalette.outlineVariantDark,
    textPrimary: GmPalette.inkDark,
    textMuted: GmPalette.mutedDark,
    accent: GmPalette.amberLight,
    onAccent: GmPalette.onAmberLight,
    accentSoft: GmPalette.amberContainerDark,
    onAccentSoft: GmPalette.onAmberContainerDark,
    bubbleIncoming: GmPalette.surfaceContainerHighDark,
    onBubbleIncoming: GmPalette.inkDark,
    bubbleOutgoing: GmPalette.bubbleOutDark,
    onBubbleOutgoing: GmPalette.onBubbleOutDark,
    danger: GmPalette.errorDark,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? outlineVariant,
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
      outlineVariant: outlineVariant ?? this.outlineVariant,
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
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
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

/// Schémas Material 3 — l'ambre en `primary`, les neutres chauds en surfaces.
final ColorScheme messagesLightScheme = ColorScheme.fromSeed(
  seedColor: GmPalette.amber,
  brightness: Brightness.light,
).copyWith(
  primary: GmPalette.amber,
  onPrimary: GmPalette.onAmber,
  primaryContainer: GmPalette.amberContainer,
  onPrimaryContainer: GmPalette.onAmberContainer,
  surface: GmPalette.surfaceLight,
  onSurface: GmPalette.inkLight,
  onSurfaceVariant: GmPalette.mutedLight,
  surfaceContainer: GmPalette.surfaceContainerLight,
  surfaceContainerHigh: GmPalette.surfaceContainerHighLight,
  surfaceContainerHighest: GmPalette.surfaceContainerHighLight,
  outline: GmPalette.outlineLight,
  outlineVariant: GmPalette.outlineVariantLight,
  error: GmPalette.errorLight,
);

final ColorScheme messagesDarkScheme = ColorScheme.fromSeed(
  seedColor: GmPalette.amber,
  brightness: Brightness.dark,
).copyWith(
  primary: GmPalette.amberLight,
  onPrimary: GmPalette.onAmberLight,
  primaryContainer: GmPalette.amberContainerDark,
  onPrimaryContainer: GmPalette.onAmberContainerDark,
  surface: GmPalette.surfaceDark,
  onSurface: GmPalette.inkDark,
  onSurfaceVariant: GmPalette.mutedDark,
  surfaceContainer: GmPalette.surfaceContainerDark,
  surfaceContainerHigh: GmPalette.surfaceContainerHighDark,
  surfaceContainerHighest: GmPalette.surfaceContainerHighDark,
  outline: GmPalette.outlineDark,
  outlineVariant: GmPalette.outlineVariantDark,
  error: GmPalette.errorDark,
);
