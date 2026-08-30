import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Va chercher les palettes tonales de l'appareil et reconstruit l'arbre
/// lorsqu'elles arrivent — `null` tant qu'elles n'ont pas répondu, et sur les
/// plateformes qui n'en ont pas.
///
/// Pourquoi pas `DynamicColorBuilder`, qui fait déjà cette course ? Parce
/// qu'il ne rend que le `ColorScheme` qu'il en dérive, et que ce schéma-là est
/// celui de Material 3 **2021** : ses cinq `surfaceContainer` valent tous la
/// même chose (voir [messagesScheme]). Ce sont les palettes brutes qu'il nous
/// faut, pas leur mise en forme — le canal de la plateforme est le même.
class SystemPalettesBuilder extends StatefulWidget {
  const SystemPalettesBuilder({super.key, required this.builder});

  final Widget Function(MessagesPalettes? palettes) builder;

  @override
  State<SystemPalettesBuilder> createState() => _SystemPalettesBuilderState();
}

class _SystemPalettesBuilderState extends State<SystemPalettesBuilder> {
  MessagesPalettes? _palettes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final palettes = await _read();
    if (!mounted || palettes == null) return;
    setState(() => _palettes = palettes);
  }

  /// Deux sources, dans l'ordre de fidélité : les cinq palettes que le système
  /// a tirées du fond d'écran (Android 12+), sinon la couleur d'accentuation
  /// choisie par l'utilisateur (macOS, Windows, Linux), qu'on sème comme le
  /// ferait Android. Aucune des deux ailleurs — le repli ambré prendra le
  /// relais.
  Future<MessagesPalettes?> _read() async {
    try {
      final core = await DynamicColorPlugin.getCorePalette();
      if (core != null) {
        return MessagesPalettes(
          primary: core.primary,
          secondary: core.secondary,
          tertiary: core.tertiary,
          neutral: core.neutral,
          neutralVariant: core.neutralVariant,
          error: core.error,
        );
      }
    } on PlatformException {
      // Pas de palette système : on tentera la couleur d'accentuation.
    }

    try {
      final accent = await DynamicColorPlugin.getAccentColor();
      if (accent != null) return MessagesPalettes.seeded(accent);
    } on PlatformException {
      // Ni palette ni accentuation : repli ambré.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.builder(_palettes);
}
