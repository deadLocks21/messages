import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';

void main() {
  const size = Size(100, 32);
  const black = Color(0xFF000000);

  /// Peint la piste et rend ses pixels, pour aller y regarder de près.
  Future<ByteData> pixelsOf({
    required double progress,
    Waveform waveform = const Waveform([]),
  }) async {
    final recorder = PictureRecorder();
    AudioTrackPainter(
      progress: progress,
      color: black,
      waveform: waveform,
    ).paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    return (await image.toByteData())!;
  }

  /// Opacité maximale rencontrée dans la colonne [x] — 255 pour ce qui est
  /// joué, bien moins pour ce qui reste.
  int alphaAt(ByteData pixels, int x) {
    var strongest = 0;
    for (var y = 0; y < size.height; y++) {
      final alpha = pixels.getUint8(((y * size.width.toInt()) + x) * 4 + 3);
      if (alpha > strongest) strongest = alpha;
    }
    return strongest;
  }

  group('AudioTrackPainter', () {
    // Toutes les barres à hauteur pleine : ce qu'on regarde ici est la
    // couleur, pas le relief.
    final full = Waveform(List.filled(20, 1));

    test('la barre en cours se remplit, elle ne bascule pas d\'un coup', () async {
      // 100 px de large, une barre tous les 5 px : à 51 %, le trait de partage
      // tombe *dans* la barre qui commence à 50.
      final pixels = await pixelsOf(progress: 0.51, waveform: full);

      expect(alphaAt(pixels, 50), 255, reason: 'le début de la barre est joué');
      expect(
        alphaAt(pixels, 52),
        lessThan(255),
        reason: 'sa fin ne l\'est pas encore',
      );
    });

    test('tout ce qui précède est plein, tout ce qui suit est en retrait', () async {
      final pixels = await pixelsOf(progress: 0.5, waveform: full);

      expect(alphaAt(pixels, 10), 255);
      expect(alphaAt(pixels, 40), 255);
      expect(alphaAt(pixels, 60), lessThan(255));
      expect(alphaAt(pixels, 90), lessThan(255));
    });

    test('au repos, aucune barre n\'est jouée', () async {
      final pixels = await pixelsOf(progress: 0, waveform: full);

      expect(alphaAt(pixels, 1), lessThan(255));
      expect(alphaAt(pixels, 50), lessThan(255));
    });

    test('sans mesure, la piste reste la ligne pointillée', () async {
      // Les points sont fins et espacés : entre deux, il n'y a rien du tout.
      // Une piste de barres, elle, ne laisse pas de colonne vide.
      final pixels = await pixelsOf(progress: 0);

      final empty = [
        for (var x = 20; x < 80; x++) if (alphaAt(pixels, x) == 0) x,
      ];
      expect(empty, isNotEmpty);
    });
  });
}
