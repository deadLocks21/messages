import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/ui/utils/sms_segments.dart';

import '../builders/builders.dart';

void main() {
  group('ReactionCodec — ce qu\'on émet', () {
    test('les emoji qui ont un tapback partent sous le verbe d\'iOS', () {
      expect(
        ReactionCodec.encode(emoji: '👍', target: 'On se voit demain ?'),
        'Liked “On se voit demain ?”',
      );
      expect(
        ReactionCodec.encode(emoji: '😍', target: 'Bonjour'),
        'Loved “Bonjour”',
      );
      expect(
        ReactionCodec.encode(emoji: '😂', target: 'Bonjour'),
        'Laughed at “Bonjour”',
      );
      expect(
        ReactionCodec.encode(emoji: '😮', target: 'Bonjour'),
        'Emphasized “Bonjour”',
      );
      expect(
        ReactionCodec.encode(emoji: '👎', target: 'Bonjour'),
        'Disliked “Bonjour”',
      );
    });

    test('les autres partent sous la forme emoji d\'iOS 18', () {
      expect(
        ReactionCodec.encode(emoji: '😢', target: 'Bonjour'),
        'Reacted 😢 to “Bonjour”',
      );
      expect(
        ReactionCodec.encode(emoji: '🎉', target: 'Bonjour'),
        'Reacted 🎉 to “Bonjour”',
      );
    });

    test('le cœur avec ou sans sélecteur de présentation est le même', () {
      expect(ReactionCodec.encode(emoji: '❤️', target: 'A'), contains('Reacted'));
      expect(
        ReactionCodec.encode(emoji: '👍️', target: 'A'),
        'Liked “A”',
      );
    });

    test('une citation trop longue est coupée, jamais dans un emoji', () {
      final long = '${'a' * 118}👨‍👩‍👧 la suite';
      final encoded = ReactionCodec.encode(emoji: '👍', target: long);

      expect(encoded, endsWith('…”'));
      expect(encoded.contains('👨‍👩‍👧'), isFalse);
      expect(encoded.runes.length, lessThan(130));
    });

    test('un message sans texte est cité par sa pièce jointe', () {
      final photo = Build.message(
        body: '',
        attachments: [Build.attachment(mimeType: 'image/jpeg')],
      );
      final vocal = Build.message(
        body: '',
        attachments: [Build.attachment(mimeType: 'audio/amr')],
      );

      expect(ReactionCodec.targetOf(photo), 'an image');
      expect(ReactionCodec.targetOf(vocal), 'an audio message');
      expect(
        ReactionCodec.targetOf(Build.message(body: 'Coucou')),
        'Coucou',
      );
    });

    test('le retrait dit ce qu\'il retire', () {
      expect(
        ReactionCodec.encodeRemoval(emoji: '😍', target: 'Bonjour'),
        'Removed a heart from “Bonjour”',
      );
      expect(
        ReactionCodec.encodeRemoval(emoji: '🎉', target: 'Bonjour'),
        'Removed a reaction from “Bonjour”',
      );
    });
  });

  test('une réaction citant un long message coûte plusieurs SMS', () {
    // L'emoji fait basculer le SMS en UCS-2 : 70 caractères par segment. On
    // cite quand même largement — une citation trop courte ne retrouverait pas
    // sa cible à l'arrivée, et la réaction s'afficherait en toutes lettres chez
    // le correspondant.
    final body = ReactionCodec.encode(emoji: '👍', target: 'a' * 120);

    expect(SmsSegments.of(body).count, greaterThan(1));
  });

  group('ReactionCodec — ce qu\'on décode', () {
    test('les six verbes d\'iOS, avec la table de Google Messages', () {
      expect(ReactionCodec.decode('Liked “Bonjour”')?.emoji, '👍');
      expect(ReactionCodec.decode('Loved “Bonjour”')?.emoji, '😍');
      expect(ReactionCodec.decode('Laughed at “Bonjour”')?.emoji, '😂');
      expect(ReactionCodec.decode('Emphasized “Bonjour”')?.emoji, '😮');
      expect(ReactionCodec.decode('Disliked “Bonjour”')?.emoji, '👎');
      expect(ReactionCodec.decode('Questioned “Bonjour”')?.emoji, '🤔');
    });

    test('les guillemets droits d\'un clavier valent les courbes d\'iOS', () {
      final decoded = ReactionCodec.decode('Liked "Bonjour"');

      expect(decoded?.emoji, '👍');
      expect(decoded?.quoted, 'Bonjour');
      expect(decoded?.wasQuoted, isTrue);
    });

    test('la forme réelle de Google Messages, invisibles compris', () {
      // Relevé dans le stock d'un Pixel, à l'octet près : Google Messages
      // encadre son emoji d'espaces de largeur nulle et sépare la citation de
      // ses guillemets par des espaces fins. Rien de tout cela ne se voit, et
      // c'est précisément ce qui faisait échouer la reconnaissance.
      const received =
          '\u200a\u200b\u{1F44D}\u200b à "\u200aJ\'ai besoin du code stp\u200a"\u200a';

      final decoded = ReactionCodec.decode(received);

      expect(decoded?.emoji, '👍');
      expect(decoded?.quoted, 'J\'ai besoin du code stp');
      expect(decoded?.wasQuoted, isTrue);
    });

    test('la forme française d\'un iPhone localisé', () {
      expect(ReactionCodec.decode('A aimé « Bonjour »')?.emoji, '👍');
      expect(ReactionCodec.decode('a adoré « Bonjour »')?.emoji, '😍');
    });

    test('la forme emoji d\'iOS 18', () {
      final decoded = ReactionCodec.decode('Reacted 😢 to “Bonjour”');

      expect(decoded?.emoji, '😢');
      expect(decoded?.quoted, 'Bonjour');
    });

    test('la forme de Google Messages, sans guillemets', () {
      final decoded = ReactionCodec.decode('😂 to Bonjour');

      expect(decoded?.emoji, '😂');
      expect(decoded?.quoted, 'Bonjour');
      expect(decoded?.wasQuoted, isFalse);
    });

    test('un retrait est reconnu comme tel', () {
      final decoded = ReactionCodec.decode('Removed a heart from “Bonjour”');

      expect(decoded?.isRemoval, isTrue);
      expect(decoded?.emoji, '😍');
      expect(decoded?.quoted, 'Bonjour');
    });

    test('un retrait qui ne dit pas lequel reste un retrait', () {
      expect(
        ReactionCodec.decode('Removed a reaction from “Bonjour”')?.isRemoval,
        isTrue,
      );
    });

    test('une phrase ordinaire n\'est pas une réaction', () {
      expect(ReactionCodec.decode('Bonjour, ça va ?'), isNull);
      expect(ReactionCodec.decode('Merci to be fair'), isNull);
      expect(ReactionCodec.decode('J\'aime bien'), isNull);
      expect(ReactionCodec.decode(''), isNull);
      expect(ReactionCodec.decode('Liked'), isNull);
    });

    test('une citation coupée par le provider se lit quand même', () {
      // Le `snippet` d'un fil est tronqué par Android : le guillemet fermant
      // n'y est plus.
      final decoded = ReactionCodec.decode('Liked “Tu es dispo ce soir po');

      expect(decoded?.emoji, '👍');
      expect(decoded?.quoted, 'Tu es dispo ce soir po');
      expect(decoded?.wasQuoted, isTrue);
    });

    test('le libellé d\'une pièce jointe se reconnaît', () {
      final decoded = ReactionCodec.decode('Liked an image');

      expect(decoded?.emoji, '👍');
      expect(decoded?.wasQuoted, isFalse);
      expect(ReactionCodec.isAttachmentLabel(decoded!.quoted), isTrue);
      expect(ReactionCodec.isAttachmentLabel('votre image'), isTrue);
      expect(ReactionCodec.isAttachmentLabel('Bonjour'), isFalse);
    });
  });

  group('ReactionCodec — l\'aller-retour', () {
    test('tout ce qu\'on émet, on sait le relire', () {
      for (final emoji in [...ReactionCodec.palette, '🎉', '🤔']) {
        const body = 'On se retrouve où ?';
        final decoded = ReactionCodec.decode(
          ReactionCodec.encode(emoji: emoji, target: body),
        );

        expect(decoded, isNotNull, reason: emoji);
        expect(decoded!.emoji, emoji, reason: emoji);
        expect(decoded.quoted, body, reason: emoji);
        expect(decoded.isRemoval, isFalse, reason: emoji);
      }
    });

    test('et tout ce qu\'on retire aussi', () {
      for (final emoji in ReactionCodec.palette) {
        final decoded = ReactionCodec.decode(
          ReactionCodec.encodeRemoval(emoji: emoji, target: 'Bonjour'),
        );

        expect(decoded?.isRemoval, isTrue, reason: emoji);
        expect(decoded?.quoted, 'Bonjour', reason: emoji);
      }
    });
  });

  group('ReactionCodec — retrouver la cible', () {
    test('une citation entière retrouve son message', () {
      expect(
        ReactionCodec.matches('Bonjour', 'Bonjour', asPrefix: true),
        isTrue,
      );
    });

    test('une citation coupée retrouve le début de son message', () {
      expect(
        ReactionCodec.matches(
          'Le début du message',
          'Le début du message et toute sa suite',
          asPrefix: true,
        ),
        isTrue,
      );
    });

    test('la casse, les espaces et les guillemets ne comptent pas', () {
      expect(
        ReactionCodec.matches('bonjour  «toi»', 'Bonjour “toi”', asPrefix: true),
        isTrue,
      );
    });

    test('sans guillemets, il faut le message entier', () {
      expect(
        ReactionCodec.matches('demain', 'demain matin', asPrefix: false),
        isFalse,
      );
      expect(
        ReactionCodec.matches('demain', 'Demain', asPrefix: false),
        isTrue,
      );
    });
  });
}
