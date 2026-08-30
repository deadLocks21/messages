import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Assemble les thèmes Material 3 clair/sombre.
///
/// Les couleurs viennent des palettes de l'appareil (`AppColors.from`), pas
/// d'ici : ce fichier n'assemble que les formes, les tailles et la typo.
///
/// Typo : **Roboto**, la police système d'Android — Google Sans n'étant pas
/// distribuée, c'est ce qui rapproche le plus l'app de l'originale sur les
/// plateformes de développement (macOS, web).
///
/// Deux constantes portent la mise en page de l'app d'origine : [panelRadius],
/// le rayon des coins hauts du panneau de contenu posé sur le fond pêche, et
/// [cardRadius], celui des cartes et des champs.
abstract final class AppThemeData {
  /// Coins hauts du panneau de contenu (liste, fil).
  static const panelRadius = 28.0;

  /// Cartes de la recherche, des contacts et des paramètres.
  static const cardRadius = 20.0;

  /// [palettes] : les palettes tonales du système (Android 12+), ou `null` là
  /// où la plateforme n'en expose pas — auquel cas on retombe sur celles
  /// semées sur l'ambre de l'app d'origine.
  static ThemeData buildLightTheme([MessagesPalettes? palettes]) =>
      _buildFrom(palettes, Brightness.light);

  static ThemeData buildDarkTheme([MessagesPalettes? palettes]) =>
      _buildFrom(palettes, Brightness.dark);

  static ThemeData _buildFrom(MessagesPalettes? palettes, Brightness b) {
    final p = palettes ?? MessagesPalettes.fallback;
    return _build(messagesScheme(p, b), AppColors.from(p, b), b);
  }

  static ThemeMode toFlutterThemeMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  static ThemeData _build(
    ColorScheme scheme,
    AppColors colors,
    Brightness brightness,
  ) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final textTheme = GoogleFonts.robotoTextTheme(base.textTheme);

    return base.copyWith(
      // Le fond de l'app est la teinte pêche : c'est le panneau de contenu qui
      // pose le blanc cassé par-dessus, coins hauts arrondis.
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Le titre de l'app d'origine n'est pas gras : c'est du corps de texte
        // en grand.
        titleTextStyle: GoogleFonts.roboto(
          textStyle: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w400,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
        actionsIconTheme: IconThemeData(color: colors.textPrimary, size: 24),
      ),
      // Le FAB « Démarrer une discussion » : le ton vif que lui réserve l'app
      // d'origine, pas d'ombre marquée.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.fab,
        foregroundColor: colors.onFab,
        elevation: 2,
        highlightElevation: 3,
        extendedTextStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textPrimary,
        textColor: colors.textPrimary,
        titleTextStyle: GoogleFonts.roboto(
          textStyle: TextStyle(color: colors.textPrimary, fontSize: 16),
        ),
        subtitleTextStyle: GoogleFonts.roboto(
          textStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      // Les menus « ⋮ » de l'app d'origine : fond pêche, coins très arrondis,
      // entrées aérées.
      popupMenuTheme: PopupMenuThemeData(
        color: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        textStyle: GoogleFonts.roboto(
          textStyle: TextStyle(color: colors.textPrimary, fontSize: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.accentSoft,
        side: BorderSide(color: colors.outline),
        labelStyle: GoogleFonts.roboto(
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          minimumSize: const Size(0, 48),
          textStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: colors.outline),
          textStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      // Champs sans bordure sur fond plein : la barre de recherche et le champ
      // de rédaction de Google Messages sont des pilules pleines.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 17),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(panelRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.textPrimary,
        contentTextStyle: TextStyle(color: colors.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
