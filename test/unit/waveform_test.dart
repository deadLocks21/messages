import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/waveform.dart';

void main() {
  group('Waveform', () {
    test('sans mesure, la silhouette est vide', () {
      expect(Waveform.empty.isEmpty, isTrue);
      expect(Waveform.empty.resampled(8), isEmpty);
    });

    test('rééchantillonner à zéro tranche ne rend rien', () {
      expect(const Waveform([0.1, 0.9]).resampled(0), isEmpty);
    });

    test('au même nombre de tranches, les niveaux ne bougent pas', () {
      const levels = [0.1, 0.5, 0.9];
      expect(const Waveform(levels).resampled(3), levels);
    });

    test('en réduisant, chaque tranche garde son maximum', () {
      // Moyenner aplatirait les attaques : c'est le pic qui doit rester.
      const waveform = Waveform([0.1, 0.9, 0.2, 0.4]);
      expect(waveform.resampled(2), [0.9, 0.4]);
    });

    test('en agrandissant, aucune tranche ne reste vide', () {
      final levels = const Waveform([0.2, 0.8]).resampled(6);
      expect(levels, hasLength(6));
      expect(levels, everyElement(greaterThan(0)));
    });
  });
}
