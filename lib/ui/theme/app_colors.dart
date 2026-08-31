// messages — les couleurs ne sont pas à l'app, elles sont à l'appareil.
//
// Google Messages ne porte pas de palette : il porte des **tons**, appliqués
// aux palettes tonales que le système tire du fond d'écran (Material You).
// Ce fichier fait la même chose — les tons de [GmTones] sont relevés sur
// l'app d'origine, pixel par pixel, sur un émulateur Android 16.
//
// Pattern kidflix/motorz conservé : palettes brutes + ThemeExtension
// `AppColors` + `context.appColors`.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Ce qui reste écrit en dur, faute de système à interroger.
abstract final class GmPalette {
  /// Teinte de repli — l'ambre des captures de l'app d'origine. Ne sert que là
  /// où le système n'expose pas ses palettes (Android < 12, iOS, web, bureau).
  static const amber = Color(0xFF8A5100);

  /// Couleurs d'avatar, dans l'ordre des créneaux rendus par
  /// `AvatarPaletteService.slotFor` (8 créneaux, initiale toujours blanche).
  ///
  /// Celles-ci ne suivent **pas** le thème, et c'est délibéré : sur
  /// l'émulateur, dont la palette est bleue, Google Messages affiche toujours
  /// ses pastilles jaune et orange. Elles servent à distinguer les
  /// correspondants, pas à décorer.
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

/// Un ton en clair, son pendant en sombre.
typedef GmTone = ({int light, int dark});

/// **Les tons relevés sur Google Messages.**
///
/// Chaque ligne dit : dans quelle palette puiser, et à quel ton. C'est tout ce
/// que l'app fixe de ses couleurs ; le reste appartient à l'appareil.
///
/// Relevé sur un émulateur Android 16 (palette système bleu-lavande), écran de
/// liste et écran de fil, en clair puis en sombre. La plupart de ces tons sont
/// ceux des rôles Material 3 standard (92/12 pour les conteneurs, 40/80 pour
/// `primary`…) ; trois ne le sont pas et sont signalés comme tels.
abstract final class GmTones {
  /// Panneau de contenu — le blanc cassé posé sur le fond, coins hauts
  /// arrondis. Relevé #F8F5FF / #05092F.
  static const GmTone surface = (light: 97, dark: 5);

  /// Barres, fond d'écran, bulles reçues, champs de saisie : dans l'app
  /// d'origine c'est **une seule et même couleur**. Relevé #E6E6FF / #161E40.
  static const GmTone background = (light: 92, dark: 11);

  static const GmTone textPrimary = (light: 10, dark: 90);
  static const GmTone textMuted = (light: 30, dark: 80);
  static const GmTone outline = (light: 50, dark: 60);
  static const GmTone outlineVariant = (light: 80, dark: 30);

  /// Accent : liens, pastille de non-lus, bouton d'envoi. Relevé #0055D5.
  static const GmTone accent = (light: 40, dark: 80);
  static const GmTone onAccent = (light: 100, dark: 20);

  /// Conteneur d'accent — bandeaux, puce de filtre, fil sélectionné. C'est le
  /// `primaryContainer` de Material 3, celui de la bulle envoyée en clair.
  static const GmTone accentSoft = (light: 90, dark: 30);
  static const GmTone onAccentSoft = (light: 10, dark: 90);

  /// FAB « Démarrer une discussion ». **Hors rôles standard** : ni `primary`
  /// (t40) ni `primaryContainer` (t90), mais un ton médian, et le *même* en
  /// clair et en sombre — relevé #789DFF dans les deux modes, libellé #001E58.
  static const GmTone fab = (light: 66, dark: 66);
  static const GmTone onFab = (light: 14, dark: 14);

  /// Bulle envoyée. En clair c'est `primaryContainer` (t90) ; en sombre l'app
  /// d'origine ne bascule pas sur le conteneur sombre (t30) mais garde une
  /// bulle **claire à texte foncé** — relevé #DAE2FF / #A7BAFF.
  static const GmTone bubbleOutgoing = (light: 90, dark: 77);

  /// Le texte de la bulle envoyée est le même bleu-nuit dans les deux modes,
  /// puisque la bulle reste claire. Relevé #13183D / #141E42.
  static const GmTone onBubbleOutgoing = (light: 10, dark: 10);

  /// Le bouton du message vocal, à droite du champ. La seule chose de l'app
  /// qui puise dans la palette **tertiaire** — d'où sa couleur, qui n'est
  /// celle d'aucun autre bouton : rose sur un appareil bleu (relevé #FFD6F7),
  /// vert sur un appareil pêche (relevé #DBE9A0). C'est le `tertiaryContainer`
  /// de Material 3.
  static const GmTone voice = (light: 90, dark: 30);
  static const GmTone onVoice = (light: 10, dark: 90);

  /// Le lecteur d'un vocal dans sa bulle : le bouton, la tête de lecture, la
  /// part déjà jouée de la piste. Ni l'accent de l'app, ni le texte de la
  /// bulle — un ton médian de la palette **neutre variante**, relevé #8D95D6
  /// sur l'émulateur (bulle claire, thème clair).
  ///
  /// Pourquoi un ton médian plutôt que le texte de la bulle : le lecteur est
  /// une commande, pas une phrase. Peint au contraste du texte il écraserait
  /// la bulle ; peint plus pâle il s'y dissoudrait. L'app d'origine le tient
  /// entre les deux — c'est ce qui lui donne son air de piste posée sur la
  /// bulle plutôt que de mot écrit dedans.
  ///
  /// L'écart au fond de la bulle vaut une trentaine de tons : c'est lui, plus
  /// que la valeur absolue, qui fait la lecture. En sombre les deux bulles ne
  /// vont pas du même côté — la reçue tombe à t11, l'envoyée reste claire à
  /// t77 — et un seul ton doit servir les deux : t45 se tient à trente et
  /// quelques de l'une comme de l'autre. (L'app d'origine n'a pas ce souci :
  /// ses deux bulles y sont claires, et son lecteur descend au presque-noir.)
  static const GmTone audioControl = (light: 63, dark: 45);
  static const GmTone onAudioControl = (light: 100, dark: 100);

  /// Le panneau d'enregistrement, sous le champ de rédaction. Puise dans la
  /// palette **secondaire** — ni le fond (`background`), ni la bulle
  /// (`accentSoft`) : un panneau qui prendrait le ton du fond ne se
  /// détacherait plus du fil qu'il recouvre.
  ///
  /// Relevé #DAE5FB sur l'émulateur, #F1E3D0 sur l'appareil pêche. Le
  /// `secondaryContainer` reconstruit ici en donne #DFE0FF : la teinte n'est
  /// pas au pixel près, l'app d'origine ne dérivant pas ses palettes tout à
  /// fait comme nous. C'est le rôle qui est juste — et il est le seul, entre
  /// le fond et la bulle, à tenir cette place-là.
  static const GmTone panel = (light: 90, dark: 30);
  static const GmTone onPanel = (light: 10, dark: 90);

  /// Le bouton d'enregistrement au milieu du panneau : le ton médian de la
  /// même palette secondaire — relevé #3C4279, un indigo sourd et non le
  /// presque-noir du texte.
  static const GmTone record = (light: 40, dark: 80);
  static const GmTone onRecord = (light: 100, dark: 20);

  static const GmTone danger = (light: 40, dark: 80);
}

/// Les cinq palettes tonales de Material You : celles du système quand il en
/// expose (Android 12+), sinon celles semées sur [GmPalette.amber].
@immutable
class MessagesPalettes {
  const MessagesPalettes({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.neutralVariant,
    required this.error,
  });

  /// Reconstitue les palettes à la façon d'Android (« tonal spot ») à partir
  /// d'une teinte : même recette de chroma, pour que le repli se comporte
  /// comme le système et non comme une palette à part.
  factory MessagesPalettes.seeded(Color seed) {
    final hct = Hct.fromInt(seed.toARGB32());
    return MessagesPalettes(
      primary: TonalPalette.of(hct.hue, math.max(48, hct.chroma)),
      secondary: TonalPalette.of(hct.hue, 16),
      tertiary: TonalPalette.of(hct.hue + 60, 24),
      neutral: TonalPalette.of(hct.hue, 4),
      neutralVariant: TonalPalette.of(hct.hue, 8),
      error: TonalPalette.of(25, 84),
    );
  }

  final TonalPalette primary;
  final TonalPalette secondary;
  final TonalPalette tertiary;

  /// Les neutres — d'où viennent le fond, le panneau et le texte. Sur Android
  /// ils ne sont pas gris : ils portent une pointe de la teinte dominante.
  final TonalPalette neutral;
  final TonalPalette neutralVariant;

  final TonalPalette error;

  /// Le repli, quand le système ne dit rien.
  static final MessagesPalettes fallback = MessagesPalettes.seeded(
    GmPalette.amber,
  );
}

extension _Tones on TonalPalette {
  Color tone(int value) => Color(get(value));
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
    required this.fab,
    required this.onFab,
    required this.bubbleIncoming,
    required this.onBubbleIncoming,
    required this.bubbleOutgoing,
    required this.onBubbleOutgoing,
    required this.voice,
    required this.onVoice,
    required this.audioControl,
    required this.onAudioControl,
    required this.panel,
    required this.onPanel,
    required this.record,
    required this.onRecord,
    required this.danger,
  });

  /// Applique le relevé de [GmTones] aux palettes de l'appareil.
  factory AppColors.from(MessagesPalettes p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    int t(GmTone tone) => isDark ? tone.dark : tone.light;

    final background = p.neutral.tone(t(GmTones.background));
    final onSurface = p.neutral.tone(t(GmTones.textPrimary));

    return AppColors(
      background: background,
      surface: p.neutral.tone(t(GmTones.surface)),
      // Champs et bulles reçues partagent la couleur des barres : c'est ce que
      // fait l'app d'origine, où le composeur et le fond d'en-tête sont
      // exactement le même bleu-lavande.
      surfaceAlt: background,
      outline: p.neutralVariant.tone(t(GmTones.outline)),
      outlineVariant: p.neutralVariant.tone(t(GmTones.outlineVariant)),
      textPrimary: onSurface,
      textMuted: p.neutralVariant.tone(t(GmTones.textMuted)),
      accent: p.primary.tone(t(GmTones.accent)),
      onAccent: p.primary.tone(t(GmTones.onAccent)),
      accentSoft: p.primary.tone(t(GmTones.accentSoft)),
      onAccentSoft: p.primary.tone(t(GmTones.onAccentSoft)),
      fab: p.primary.tone(t(GmTones.fab)),
      onFab: p.primary.tone(t(GmTones.onFab)),
      bubbleIncoming: background,
      onBubbleIncoming: onSurface,
      bubbleOutgoing: p.primary.tone(t(GmTones.bubbleOutgoing)),
      onBubbleOutgoing: p.neutral.tone(t(GmTones.onBubbleOutgoing)),
      voice: p.tertiary.tone(t(GmTones.voice)),
      onVoice: p.tertiary.tone(t(GmTones.onVoice)),
      audioControl: p.neutralVariant.tone(t(GmTones.audioControl)),
      onAudioControl: p.neutralVariant.tone(t(GmTones.onAudioControl)),
      panel: p.secondary.tone(t(GmTones.panel)),
      onPanel: p.secondary.tone(t(GmTones.onPanel)),
      record: p.secondary.tone(t(GmTones.record)),
      onRecord: p.secondary.tone(t(GmTones.onRecord)),
      danger: p.error.tone(t(GmTones.danger)),
    );
  }

  /// Fond d'écran et barres — la teinte sur laquelle tout se pose.
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
  final Color accent; // pastille de non-lus, envoi, sélection
  final Color onAccent;
  final Color accentSoft; // bandeaux, puces, sélection
  final Color onAccentSoft;

  /// Le FAB, et lui seul : l'app d'origine lui donne un ton à part, plus vif
  /// que [accentSoft] et identique en clair comme en sombre.
  final Color fab;
  final Color onFab;
  final Color bubbleIncoming;
  final Color onBubbleIncoming;
  final Color bubbleOutgoing;
  final Color onBubbleOutgoing;

  /// Le bouton du message vocal — la seule tache de tertiaire de l'app.
  final Color voice;
  final Color onVoice;

  /// Le lecteur d'un vocal reçu ou envoyé, dans sa bulle.
  final Color audioControl;
  final Color onAudioControl;

  /// Le panneau d'enregistrement, posé sous le champ de rédaction.
  final Color panel;
  final Color onPanel;

  /// Le bouton qui ouvre le micro, au milieu de ce panneau.
  final Color record;
  final Color onRecord;

  final Color danger; // échec d'envoi, suppression

  /// Couleur de la pastille d'avatar pour un créneau donné.
  static Color avatarColor(int slot) =>
      GmPalette.avatarSlots[slot % GmPalette.avatarSlots.length];

  /// Repli, hors Android 12+.
  static final AppColors light = AppColors.from(
    MessagesPalettes.fallback,
    Brightness.light,
  );
  static final AppColors dark = AppColors.from(
    MessagesPalettes.fallback,
    Brightness.dark,
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
    Color? fab,
    Color? onFab,
    Color? bubbleIncoming,
    Color? onBubbleIncoming,
    Color? bubbleOutgoing,
    Color? onBubbleOutgoing,
    Color? voice,
    Color? onVoice,
    Color? audioControl,
    Color? onAudioControl,
    Color? panel,
    Color? onPanel,
    Color? record,
    Color? onRecord,
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
      fab: fab ?? this.fab,
      onFab: onFab ?? this.onFab,
      bubbleIncoming: bubbleIncoming ?? this.bubbleIncoming,
      onBubbleIncoming: onBubbleIncoming ?? this.onBubbleIncoming,
      bubbleOutgoing: bubbleOutgoing ?? this.bubbleOutgoing,
      onBubbleOutgoing: onBubbleOutgoing ?? this.onBubbleOutgoing,
      voice: voice ?? this.voice,
      onVoice: onVoice ?? this.onVoice,
      audioControl: audioControl ?? this.audioControl,
      onAudioControl: onAudioControl ?? this.onAudioControl,
      panel: panel ?? this.panel,
      onPanel: onPanel ?? this.onPanel,
      record: record ?? this.record,
      onRecord: onRecord ?? this.onRecord,
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
      fab: Color.lerp(fab, other.fab, t)!,
      onFab: Color.lerp(onFab, other.onFab, t)!,
      bubbleIncoming: Color.lerp(bubbleIncoming, other.bubbleIncoming, t)!,
      onBubbleIncoming: Color.lerp(onBubbleIncoming, other.onBubbleIncoming, t)!,
      bubbleOutgoing: Color.lerp(bubbleOutgoing, other.bubbleOutgoing, t)!,
      onBubbleOutgoing: Color.lerp(onBubbleOutgoing, other.onBubbleOutgoing, t)!,
      voice: Color.lerp(voice, other.voice, t)!,
      onVoice: Color.lerp(onVoice, other.onVoice, t)!,
      audioControl: Color.lerp(audioControl, other.audioControl, t)!,
      onAudioControl: Color.lerp(onAudioControl, other.onAudioControl, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      onPanel: Color.lerp(onPanel, other.onPanel, t)!,
      record: Color.lerp(record, other.record, t)!,
      onRecord: Color.lerp(onRecord, other.onRecord, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Raccourci d'accès : `context.appColors.accent`.
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

/// Le [ColorScheme] Material 3 servi aux widgets du framework.
///
/// Reconstruit à la main depuis les palettes plutôt que pris tel quel : le
/// schéma que rend `dynamic_color` est celui de Material 3 **2021**, où les
/// cinq niveaux de `surfaceContainer` n'existent pas encore et retombent tous
/// sur la même valeur. Un `BottomSheet` ou un `Card` s'y peindraient d'un blanc
/// plat, là où l'app d'origine les empile.
///
/// Les tons sont ceux de la spécification Material 3, sauf `surface`, repris de
/// [GmTones] pour que le framework et l'app parlent de la même couleur.
ColorScheme messagesScheme(MessagesPalettes p, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  int t(GmTone tone) => isDark ? tone.dark : tone.light;

  return ColorScheme(
    brightness: brightness,
    primary: p.primary.tone(isDark ? 80 : 40),
    onPrimary: p.primary.tone(isDark ? 20 : 100),
    primaryContainer: p.primary.tone(isDark ? 30 : 90),
    onPrimaryContainer: p.primary.tone(isDark ? 90 : 10),
    secondary: p.secondary.tone(isDark ? 80 : 40),
    onSecondary: p.secondary.tone(isDark ? 20 : 100),
    secondaryContainer: p.secondary.tone(isDark ? 30 : 90),
    onSecondaryContainer: p.secondary.tone(isDark ? 90 : 10),
    tertiary: p.tertiary.tone(isDark ? 80 : 40),
    onTertiary: p.tertiary.tone(isDark ? 20 : 100),
    tertiaryContainer: p.tertiary.tone(isDark ? 30 : 90),
    onTertiaryContainer: p.tertiary.tone(isDark ? 90 : 10),
    error: p.error.tone(isDark ? 80 : 40),
    onError: p.error.tone(isDark ? 20 : 100),
    errorContainer: p.error.tone(isDark ? 30 : 90),
    onErrorContainer: p.error.tone(isDark ? 90 : 10),
    surface: p.neutral.tone(t(GmTones.surface)),
    onSurface: p.neutral.tone(t(GmTones.textPrimary)),
    surfaceDim: p.neutral.tone(isDark ? 6 : 87),
    surfaceBright: p.neutral.tone(isDark ? 24 : 98),
    surfaceContainerLowest: p.neutral.tone(isDark ? 4 : 100),
    surfaceContainerLow: p.neutral.tone(isDark ? 10 : 96),
    surfaceContainer: p.neutral.tone(isDark ? 12 : 94),
    surfaceContainerHigh: p.neutral.tone(isDark ? 17 : 92),
    surfaceContainerHighest: p.neutral.tone(isDark ? 22 : 90),
    onSurfaceVariant: p.neutralVariant.tone(t(GmTones.textMuted)),
    outline: p.neutralVariant.tone(t(GmTones.outline)),
    outlineVariant: p.neutralVariant.tone(t(GmTones.outlineVariant)),
    inverseSurface: p.neutral.tone(isDark ? 90 : 20),
    onInverseSurface: p.neutral.tone(isDark ? 20 : 95),
    inversePrimary: p.primary.tone(isDark ? 40 : 80),
    shadow: p.neutral.tone(0),
    scrim: p.neutral.tone(0),
    surfaceTint: p.primary.tone(isDark ? 80 : 40),
  );
}
