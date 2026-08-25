import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/address.dart';

void main() {
  group('Address', () {
    test('deux formes du même numéro sont égales', () {
      expect(Address.parse('+33612345678'), Address.parse('0612345678'));
      expect(Address.parse('+33612345678'), Address.parse('06 12 34 56 78'));
      expect(
        Address.parse('+33612345678').hashCode,
        Address.parse('0612345678').hashCode,
      );
    });

    test('deux numéros différents ne sont pas égaux', () {
      expect(Address.parse('0612345678'), isNot(Address.parse('0612345679')));
    });

    test('formate un mobile français par groupes de deux', () {
      expect(Address.parse('+33612345678').display, '06 12 34 56 78');
      expect(Address.parse('0612345678').display, '06 12 34 56 78');
    });

    test('laisse intacte une adresse non formatable', () {
      expect(Address.parse('ORANGE').display, 'ORANGE');
      expect(Address.parse('+15551234567').display, '+15551234567');
    });

    test('reconnaît numéros courts et expéditeurs alphanumériques', () {
      expect(Address.parse('36002').isShortCode, isTrue);
      expect(Address.parse('ORANGE').isAlphanumeric, isTrue);
      expect(Address.parse('0612345678').isShortCode, isFalse);
      expect(Address.parse('0612345678').isAlphanumeric, isFalse);
    });

    test('refuse une adresse vide, tolère l\'absence de valeur', () {
      expect(() => Address.parse('  '), throwsFormatException);
      expect(Address.tryParse(null), isNull);
      expect(Address.tryParse(''), isNull);
      expect(Address.tryParse(' 36002 ')?.raw, '36002');
    });
  });
}
