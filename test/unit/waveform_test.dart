import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/infrastructure/audio/in_memory.audio_waveform.service.dart';

void main() {
  group('Waveform', () {
    test('se ramène au nombre de barres demandé', () {
      const waveform = Waveform([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]);
      expect(waveform.resampled(4), hasLength(4));
      expect(waveform.resampled(1), hasLength(1));
    });

    test('garde les pointes plutôt que de les moyenner', () {
      // Une attaque isolée au milieu d'un silence : c'est elle qu'on doit voir.
      // Moyennée avec sa voisine, elle serait retombée à 0,5.
      const waveform = Waveform([0, 0, 1, 0, 0, 0, 0, 0]);
      final bars = waveform.resampled(4);

      expect(bars, [0, 1, 0, 0]);
    });

    test('une mesure absente ne donne aucune barre', () {
      expect(Waveform.empty.isEmpty, isTrue);
      expect(Waveform.empty.resampled(32), isEmpty);
    });

    test('un son plus court que la piste étire ses mesures', () {
      // Deux mesures pour quatre barres : chacune en occupe deux. Rendre les
      // deux mesures telles quelles laisserait la piste à moitié vide.
      const waveform = Waveform([0.2, 0.9]);

      expect(waveform.resampled(4), [0.2, 0.2, 0.9, 0.9]);
    });
  });

  group('InMemoryAudioWaveformService', () {
    const service = InMemoryAudioWaveformService();

    test('rend le nombre de tranches demandé, toutes dans les bornes', () async {
      final waveform = await service.of('part-1', buckets: 32);

      expect(waveform!.levels, hasLength(32));
      expect(waveform.levels, everyElement(inInclusiveRange(0, 1)));
    });

    test('la même pièce jointe se redessine à l\'identique', () async {
      // Une silhouette qui frémirait d'un rebuild à l'autre trahirait la
      // doublure — et rendrait tout test de rendu instable.
      final first = await service.of('part-1');
      final second = await service.of('part-1');

      expect(first!.levels, second!.levels);
    });

    test('deux vocaux ne se ressemblent pas', () async {
      final one = await service.of('part-1');
      final other = await service.of('part-2');

      expect(one!.levels, isNot(other!.levels));
    });
  });
}
