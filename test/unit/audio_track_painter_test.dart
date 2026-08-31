import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';

void main() {
  const size = Size(100, AudioTrackPainter.thumbHeight);
  const played = Color(0xFF000000);
  const remaining = Color(0x1F000000);

  /// Peint la piste et rend ses pixels, pour aller y regarder de près.
  Future<ByteData> pixelsOf(double progress) async {
    final recorder = PictureRecorder();
    AudioTrackPainter(
      progress: progress,
      color: played,
      trackColor: remaining,
    ).paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    return (await image.toByteData())!;
  }

  /// Opacité maximale rencontrée dans la colonne [x] — 255 pour ce qui est
  /// joué, bien moins pour ce qui reste, rien du tout dans les deux respirations
  /// qui encadrent la tête de lecture.
  int alphaAt(ByteData pixels, int x) {
    var strongest = 0;
    for (var y = 0; y < size.height; y++) {
      final alpha = pixels.getUint8(((y * size.width.toInt()) + x) * 4 + 3);
      if (alpha > strongest) strongest = alpha;
    }
    return strongest;
  }

  /// Hauteur peinte dans la colonne [x] : 16 px pour la piste, 44 pour la tête.
  int heightAt(ByteData pixels, int x) {
    var painted = 0;
    for (var y = 0; y < size.height; y++) {
      if (pixels.getUint8(((y * size.width.toInt()) + x) * 4 + 3) > 0) {
        painted++;
      }
    }
    return painted;
  }

  group('AudioTrackPainter', () {
    test('ce qui est joué est plein, ce qui reste est en retrait', () async {
      // 100 px de large, une tête de 4 : son centre est à 2 + 96 × 0,5 = 50.
      final pixels = await pixelsOf(0.5);

      expect(alphaAt(pixels, 10), 255, reason: 'la part jouée');
      expect(alphaAt(pixels, 30), 255);
      expect(alphaAt(pixels, 70), lessThan(255), reason: 'la part qui reste');
      expect(alphaAt(pixels, 70), greaterThan(0));
    });

    test('la tête de lecture respire des deux côtés', () async {
      final pixels = await pixelsOf(0.5);

      expect(alphaAt(pixels, 45), 0, reason: 'entre la part jouée et la tête');
      expect(alphaAt(pixels, 50), 255, reason: 'la tête');
      expect(alphaAt(pixels, 55), 0, reason: 'entre la tête et la part restante');
    });

    test('la tête est une barre, plus haute que la piste', () async {
      final pixels = await pixelsOf(0.5);

      expect(heightAt(pixels, 50), AudioTrackPainter.thumbHeight);
      expect(heightAt(pixels, 30), AudioTrackPainter.trackHeight);
    });

    test('au repos, rien n\'est joué et la tête est au départ', () async {
      final pixels = await pixelsOf(0);

      expect(alphaAt(pixels, 2), 255, reason: 'la tête, collée au bord');
      expect(heightAt(pixels, 2), AudioTrackPainter.thumbHeight);
      expect(alphaAt(pixels, 30), lessThan(255));
    });

    test('la pastille marque la fin de la piste', () async {
      final pixels = await pixelsOf(0);

      // Elle est pleine là où la piste qui l'entoure est en retrait : sans
      // elle, une piste presque finie n'aurait plus de bout visible.
      expect(alphaAt(pixels, 92), 255);
      expect(alphaAt(pixels, 80), lessThan(255));
    });

    test('arrivée au bout, la tête a mangé la pastille', () async {
      final pixels = await pixelsOf(1);

      expect(alphaAt(pixels, 98), 255, reason: 'la tête, collée à la fin');
      expect(heightAt(pixels, 98), AudioTrackPainter.thumbHeight);
      // Plus de piste restante derrière elle : la pastille n'y flotte pas
      // toute seule.
      expect(heightAt(pixels, 92), 0);
    });
  });
}
