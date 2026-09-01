import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';
import 'package:messages/ui/theme/app_theme_data.dart';
import 'package:messages/ui/utils/sms_segments.dart';

/// Tests du compteur affiché sous le champ de rédaction.
///
/// Ce compteur n'envoie rien : il annonce ce que `SmsSegments.kt` fera au
/// moment de l'envoi. Les cas repris ici sont donc **ceux de
/// `SmsSegmentsTest`** — mêmes corps, mêmes frontières — pour que la dérive
/// entre les deux règles se voie ici plutôt que sur l'écran de l'utilisateur.
void main() {
  group('SmsSegments — alphabet GSM 7 bits', () {
    test('un message court tient dans un seul SMS', () {
      expect(SmsSegments.of('').count, 1);
      expect(SmsSegments.of('Bonjour').count, 1);
      expect(SmsSegments.of('a' * 160).count, 1);
      expect(SmsSegments.of('a' * 160).encoding, SmsEncoding.gsm7bit);
    });

    test('au-delà de 160 caractères, le découpage réduit la taille utile', () {
      // 161 caractères ne tiennent plus : chaque partie perd son en-tête de
      // concaténation, d'où 153 septets utiles.
      expect(SmsSegments.of('a' * 161).count, 2);
      expect(SmsSegments.of('a' * 306).count, 2);
      expect(SmsSegments.of('a' * 307).count, 3);
    });

    test('les accents de l\'alphabet GSM ne font pas basculer en UCS-2', () {
      // « é », « à », « ù » et « è » sont dans la table par défaut : un tel
      // message garde ses 160 caractères par segment.
      final body = 'éàùè' * 40;
      expect(body.length, 160);
      expect(SmsSegments.of(body).count, 1);
      expect(SmsSegments.of(body).encoding, SmsEncoding.gsm7bit);
    });

    test('le « € » coûte deux septets', () {
      // Quatre-vingts « € » remplissent le segment à ras bord ; le
      // quatre-vingt-unième le fait déborder, alors que le compteur naïf n'y
      // voyait que 81 caractères sur 160.
      expect(SmsSegments.of('€' * 80).count, 1);
      expect(SmsSegments.of('€' * 80).remaining, 0);
      expect(SmsSegments.of('€' * 81).count, 2);
    });

    test('une paire d\'échappement ne se coupe pas en deux', () {
      // Le 153e septet tomberait au milieu de la paire : le « € » ouvre le
      // segment suivant, et laisse un septet perdu derrière lui.
      final segments = SmsSegments.of('${'a' * 152}€${'b' * 20}');
      expect(segments.count, 2);
      // Le second segment porte le « € » (2) puis vingt « b » : 131 septets
      // restent libres — un de moins que la soustraction sur les caractères.
      expect(segments.remaining, SmsSegments.septetsConcatenated - 22);
    });
  });

  group('SmsSegments — UCS-2', () {
    test(
      'un seul caractère hors alphabet GSM fait basculer tout le message',
      () {
        // « ê » n'est pas dans la table GSM : le message entier passe en UCS-2,
        // et 71 caractères ne tiennent plus dans un segment.
        final segments = SmsSegments.of('ê${'a' * 70}');
        expect(segments.encoding, SmsEncoding.ucs2);
        expect(segments.count, 2);
      },
    );

    test('70 caractères UCS-2 tiennent dans un segment', () {
      final segments = SmsSegments.of('ê' * 70);
      expect(segments.count, 1);
      expect(segments.remaining, 0);
    });

    test('le « ç » minuscule n\'est pas dans l\'alphabet GSM', () {
      // Contre-intuitif, mais conforme au 3GPP TS 23.038 comme à AOSP : la
      // table ne contient que le « Ç » majuscule.
      expect(SmsSegments.of('ç' * 71).count, 2);
      expect(SmsSegments.of('Ç' * 71).count, 1);
    });

    test('un emoji n\'est jamais coupé en deux moitiés', () {
      // 66 caractères puis un emoji : la limite de 67 unités UTF-16 tombe pile
      // au milieu de la paire de substitution, donc le premier segment rend
      // une unité et l'emoji ouvre le suivant.
      final segments = SmsSegments.of('${'ê' * 66}😀${'ê' * 20}');
      expect(segments.count, 2);
      // Le second porte l'emoji (2 unités) et vingt « ê ».
      expect(segments.remaining, SmsSegments.unitsConcatenated - 22);
    });
  });

  group('SmsSegments — ce que le compteur affichait de faux', () {
    test('un message français de 77 caractères fait bien deux segments', () {
      // Le corps du bug : le « û » de « sûre » sort de la table GSM, donc
      // UCS-2, donc deux segments. Le compteur n'apparaissait même pas, il ne
      // voyait qu'un message de 77 caractères sur 160.
      const body =
          'Réunion décalée à seize heures trente, prévois ton parapluie et ta veste sûre';
      expect(body.length, 77);

      final segments = SmsSegments.of(body);
      expect(segments.count, 2);
      expect(segments.encoding, SmsEncoding.ucs2);
      // Dix unités écrites dans le second segment : il en reste 57, et non les
      // 229 qu'annonçait la soustraction en 7 bits.
      expect(segments.remaining, 57);
    });

    test('le reste se compte dans l\'unité de l\'encodage retenu', () {
      // Même longueur de texte, deux restes différents : c'est l'encodage qui
      // décide, et c'est bien ce que le compteur doit montrer.
      expect(SmsSegments.of('a' * 200).remaining, 153 - 47);
      expect(SmsSegments.of('ê' * 200).remaining, 67 - 66);
    });
  });

  group('SmsSegments — bornes', () {
    test('le reste tient toujours dans un segment', () {
      // Le compteur est lu à chaque frappe : un reste négatif — ou plus grand
      // qu'un segment — s'afficherait tel quel sous le champ.
      const bodies = [
        '',
        'Bonjour !',
        'Où êtes-vous ? Rendez-vous à 18 h.',
        'Bonjour ! Ça va ?',
      ];
      for (final seed in bodies) {
        for (var repeat = 1; repeat <= 40; repeat++) {
          final segments = SmsSegments.of(seed * repeat);
          final capacity = switch ((segments.encoding, segments.count)) {
            (SmsEncoding.gsm7bit, 1) => SmsSegments.septetsSingle,
            (SmsEncoding.gsm7bit, _) => SmsSegments.septetsConcatenated,
            (SmsEncoding.ucs2, 1) => SmsSegments.unitsSingle,
            (SmsEncoding.ucs2, _) => SmsSegments.unitsConcatenated,
          };
          expect(segments.count, greaterThanOrEqualTo(1));
          expect(segments.remaining, inInclusiveRange(0, capacity));
        }
      }
    });
  });

  group('le compteur sous le champ', () {
    Future<TextEditingController> pumpComposer(WidgetTester tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(
                controller: controller,
                onSend: (_) {},
                enabled: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('il se montre dès qu\'un accent fait basculer en UCS-2', (
      tester,
    ) async {
      final controller = await pumpComposer(tester);
      controller.text =
          'Réunion décalée à seize heures trente, prévois ton parapluie et ta veste sûre';
      await tester.pumpAndSettle();

      // Ce que l'ancien compteur ne disait pas : deux SMS partiront, et il
      // reste 57 caractères dans le second.
      expect(
        tester.widget<Text>(find.byKey(const Key('segmentCounter'))).data,
        '57/2',
      );
    });

    testWidgets('il reste muet tant qu\'un seul SMS suffit', (tester) async {
      // Le même texte sans accent tient dans un segment : rien à annoncer.
      final controller = await pumpComposer(tester);
      controller.text = 'a' * 100;
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('segmentCounter')), findsNothing);
    });
  });
}
