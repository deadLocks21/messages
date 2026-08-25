import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';

void main() {
  group('MessageComposer.segmentsFor', () {
    test('un message court tient dans un seul SMS', () {
      expect(MessageComposer.segmentsFor(''), 1);
      expect(MessageComposer.segmentsFor('a' * 160), 1);
    });

    test('au-delà de 160 caractères, le découpage réduit la taille utile', () {
      // 161 caractères ne tiennent plus : chaque partie perd 7 caractères
      // d'en-tête de concaténation, d'où 153 utiles.
      expect(MessageComposer.segmentsFor('a' * 161), 2);
      expect(MessageComposer.segmentsFor('a' * 306), 2);
      expect(MessageComposer.segmentsFor('a' * 307), 3);
    });
  });
}
