import 'dart:typed_data';

/// Fabrique de PNG unis, pour les doublures.
///
/// Hors Android il n'y a ni galerie ni appareil photo : la démo et les tests
/// ont quand même besoin d'octets d'image *réels* — une vignette qui décode
/// vraiment prouve tout le chemin (sélection → plateau → envoi → bulle), là où
/// un tableau d'octets bidon s'arrêterait au décodeur.
///
/// Le PNG est écrit à la main, en blocs *stored* : la compression n'apporte
/// rien sur une image unie, et l'écrire sans elle évite de dépendre de quoi que
/// ce soit.
abstract final class SampleImage {
  /// PNG opaque de [width] × [height] pixels, entièrement de la couleur
  /// (`0xAARRGGBB`) donnée.
  static Uint8List solid({
    required int width,
    required int height,
    required int argb,
  }) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;

    // Données brutes : chaque ligne préfixée de son octet de filtre (0 = aucun).
    final raw = BytesBuilder();
    for (var y = 0; y < height; y++) {
      raw.addByte(0);
      for (var x = 0; x < width; x++) {
        raw
          ..addByte(r)
          ..addByte(g)
          ..addByte(b);
      }
    }

    final png = BytesBuilder()
      ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final ihdr = BytesBuilder()
      ..add(_uint32(width))
      ..add(_uint32(height))
      ..add(const [8, 2, 0, 0, 0]); // 8 bits, RGB, sans entrelacement
    png.add(_chunk('IHDR', ihdr.takeBytes()));
    png.add(_chunk('IDAT', _zlibStored(raw.takeBytes())));
    png.add(_chunk('IEND', Uint8List(0)));
    return png.takeBytes();
  }

  static Uint8List _chunk(String type, Uint8List data) {
    final body = BytesBuilder()
      ..add(type.codeUnits)
      ..add(data);
    final bytes = body.takeBytes();
    return (BytesBuilder()
          ..add(_uint32(data.length))
          ..add(bytes)
          ..add(_uint32(_crc32(bytes))))
        .takeBytes();
  }

  /// Flux zlib sans compression : en-tête, blocs *stored* de 65 535 octets au
  /// plus, puis la somme Adler-32 exigée par le format.
  static Uint8List _zlibStored(Uint8List data) {
    final out = BytesBuilder()..add(const [0x78, 0x01]);
    var offset = 0;
    do {
      final length = (data.length - offset).clamp(0, 0xFFFF);
      final last = offset + length >= data.length;
      out
        ..addByte(last ? 1 : 0)
        ..addByte(length & 0xFF)
        ..addByte((length >> 8) & 0xFF)
        ..addByte((length ^ 0xFFFF) & 0xFF)
        ..addByte(((length ^ 0xFFFF) >> 8) & 0xFF)
        ..add(data.sublist(offset, offset + length));
      offset += length;
    } while (offset < data.length);
    out.add(_uint32(_adler32(data)));
    return out.takeBytes();
  }

  static Uint8List _uint32(int value) => Uint8List(4)
    ..[0] = (value >> 24) & 0xFF
    ..[1] = (value >> 16) & 0xFF
    ..[2] = (value >> 8) & 0xFF
    ..[3] = value & 0xFF;

  static final List<int> _crcTable = List<int>.generate(256, (i) {
    var c = i;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(Uint8List bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static int _adler32(Uint8List bytes) {
    var a = 1;
    var b = 0;
    for (final byte in bytes) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    return ((b << 16) | a) & 0xFFFFFFFF;
  }
}
