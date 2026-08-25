import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Assemble les thèmes Material 3 clair/sombre.
///
/// Typo : **Roboto**, la police système d'Android — Google Sans n'étant pas
/// distribuée, c'est ce qui rapproche le plus l'app de l'originale sur les
/// plateformes de développement (macOS, web).
abstract final class AppThemeData {
  static ThemeData buildLightTheme() =>
      _build(messagesLightScheme, AppColors.light, Brightness.light);

  static ThemeData buildDarkTheme() =>
      _build(messagesDarkScheme, AppColors.dark, Brightness.dark);

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
        titleTextStyle: GoogleFonts.roboto(
          textStyle: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // Le FAB « Démarrer un chat » : bleu plein, coins très arrondis (M3).
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentSoft,
        foregroundColor: colors.onAccentSoft,
        elevation: 1,
        highlightElevation: 2,
        extendedTextStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textMuted,
        textColor: colors.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          minimumSize: const Size(0, 48),
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: colors.outline),
          textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      // Champs sans bordure sur fond gris clair : la barre de recherche et le
      // champ de rédaction de Google Messages.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.outline, space: 1, thickness: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
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
