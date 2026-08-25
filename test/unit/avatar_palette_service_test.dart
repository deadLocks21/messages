import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/avatar_palette.service.dart';

void main() {
  group('AvatarPaletteService', () {
    test('rend toujours un créneau de la palette', () {
      for (final seed in ['Alice', 'bob', '+33612345678', '36002', '']) {
        final slot = AvatarPaletteService.slotFor(seed);
        expect(slot, inInclusiveRange(0, AvatarPaletteService.slotCount - 1));
      }
    });

    test('est stable et insensible à la casse', () {
      expect(
        AvatarPaletteService.slotFor('Camille'),
        AvatarPaletteService.slotFor('  camille '),
      );
      expect(
        AvatarPaletteService.slotFor('Camille'),
        AvatarPaletteService.slotFor('Camille'),
      );
    });

    test('distingue deux interlocuteurs différents', () {
      // Pas une garantie théorique (8 créneaux, collisions possibles), mais ces
      // deux graines-là doivent tomber ailleurs : c'est ce qui rend la liste
      // lisible.
      expect(
        AvatarPaletteService.slotFor('Camille'),
        isNot(AvatarPaletteService.slotFor('Julien')),
      );
    });
  });
}
