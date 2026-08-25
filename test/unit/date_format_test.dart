import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:messages/ui/utils/date_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final now = DateTime(2026, 8, 25, 18, 30);

  group('MessagesDateFormat.conversationStamp', () {
    test('le jour même : l\'heure', () {
      expect(
        MessagesDateFormat.conversationStamp(DateTime(2026, 8, 25, 10, 24), now: now),
        '10:24',
      );
    });

    test('la veille : « hier »', () {
      expect(
        MessagesDateFormat.conversationStamp(DateTime(2026, 8, 24, 10, 24), now: now),
        'hier',
      );
    });

    test('dans la semaine : le jour abrégé', () {
      expect(
        MessagesDateFormat.conversationStamp(DateTime(2026, 8, 21, 10, 24), now: now),
        contains('ven'),
      );
    });

    test('même année, plus ancien : jour et mois', () {
      expect(
        MessagesDateFormat.conversationStamp(DateTime(2026, 3, 12, 10, 24), now: now),
        contains('12'),
      );
    });

    test('année précédente : date complète', () {
      expect(
        MessagesDateFormat.conversationStamp(DateTime(2024, 3, 12, 10, 24), now: now),
        '12/03/2024',
      );
    });
  });

  group('MessagesDateFormat.separator', () {
    test('le jour même : juste l\'heure', () {
      expect(
        MessagesDateFormat.separator(DateTime(2026, 8, 25, 10, 24), now: now),
        '10:24',
      );
    });

    test('la veille : « Hier, heure »', () {
      expect(
        MessagesDateFormat.separator(DateTime(2026, 8, 24, 10, 24), now: now),
        'Hier, 10:24',
      );
    });
  });
}
