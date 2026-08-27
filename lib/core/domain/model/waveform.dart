import 'dart:math' as math;

/// La silhouette d'un son : son intensité, découpée en tranches égales.
///
/// Normalisée entre 0 et 1, le plus fort de l'enregistrement valant 1 — deux
/// vocaux enregistrés à des volumes différents doivent se dessiner pareil, ce
/// qu'on lit d'une forme d'onde n'est pas un niveau absolu mais un relief.
class Waveform {
  /// Niveaux, du début à la fin. Vide quand le son n'a pas pu être mesuré.
  final List<double> levels;

  const Waveform(this.levels);

  static const empty = Waveform([]);

  bool get isEmpty => levels.isEmpty;

  /// Les mêmes niveaux, ramenés à [count] tranches.
  ///
  /// La piste n'a pas la même largeur d'un écran à l'autre : c'est l'affichage
  /// qui décide du nombre de barres, pas la mesure. Le rééchantillonnage garde
  /// le **maximum** de chaque intervalle plutôt que sa moyenne — moyenner
  /// aplatit les attaques, et une forme d'onde sans attaques ne ressemble plus
  /// à de la parole.
  List<double> resampled(int count) {
    if (count <= 0 || levels.isEmpty) return const [];
    if (count == levels.length) return levels;
    return List.generate(count, (index) {
      final start = index * levels.length ~/ count;
      final end = math.max(start + 1, (index + 1) * levels.length ~/ count);
      var peak = 0.0;
      for (var i = start; i < end && i < levels.length; i++) {
        if (levels[i] > peak) peak = levels[i];
      }
      return peak;
    });
  }
}
