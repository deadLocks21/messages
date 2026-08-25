import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// Le canal natif n'est pas testable sur un vrai téléphone ici : ce qui compte,
/// c'est la **traduction** entre les `Map` du canal et les modèles du domaine,
/// et celle des codes d'erreur en exceptions métier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('fr.dtfh.messages/sms');
  const channel = AndroidSmsChannel(channel: methodChannel);

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Répond à tout appel de méthode par [responses], indexé par nom de méthode.
  void mock(Map<String, Object? Function(MethodCall)> responses) {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      final handler = responses[call.method];
      if (handler == null) return null;
      return handler(call);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(methodChannel, null));

  group('AndroidSmsChannel', () {
    test('traduit un fil du provider', () async {
      mock({
        'listConversations': (_) => [
          {
            'threadId': '42',
            'recipients': ['+33612345678'],
            'snippet': 'Coucou',
            'date': 1756108800000,
            'messageCount': 3,
            'unreadCount': 1,
          },
        ],
      });

      final conversations = await channel.listConversations();

      expect(conversations.single.id, '42');
      expect(conversations.single.recipients.single, Address.parse('0612345678'));
      expect(conversations.single.unreadCount, 1);
      expect(
        conversations.single.lastMessageAt,
        DateTime.fromMillisecondsSinceEpoch(1756108800000),
      );
    });

    test('un fil sans destinataire lisible reste affichable', () async {
      mock({
        'listConversations': (_) => [
          {
            'threadId': '42',
            'recipients': <String>[],
            'snippet': '',
            'date': 0,
          },
        ],
      });

      expect((await channel.listConversations()).single.recipients, hasLength(1));
    });

    test('traduit un message et son état', () async {
      mock({
        'listMessages': (_) => [
          {
            'id': '7',
            'threadId': '42',
            'address': '+33612345678',
            'body': 'Salut',
            'date': 1756108800000,
            'direction': 'outgoing',
            'status': 'delivered',
            'read': true,
            'subscriptionId': 1,
          },
        ],
      });

      final message = (await channel.listMessages('42')).single;

      expect(message.id, '7');
      expect(message.direction, MessageDirection.outgoing);
      expect(message.status, MessageStatus.delivered);
      expect(message.subscriptionId, 1);
    });

    test('un état inconnu retombe sur « reçu » plutôt que d\'échouer', () async {
      mock({
        'listMessages': (_) => [
          {
            'id': '7',
            'threadId': '42',
            'address': '+33612345678',
            'body': 'Salut',
            'date': 0,
            'direction': 'martien',
            'status': 'inconnu',
          },
        ],
      });

      final message = (await channel.listMessages('42')).single;

      expect(message.direction, MessageDirection.incoming);
      expect(message.status, MessageStatus.received);
    });

    test('transmet les destinataires et le corps à l\'envoi', () async {
      MethodCall? captured;
      mock({
        'sendMessage': (call) {
          captured = call;
          return {
            'id': '8',
            'threadId': '42',
            'address': '+33612345678',
            'body': 'Salut',
            'date': 0,
            'direction': 'outgoing',
            'status': 'sending',
          };
        },
      });

      final sent = await channel.sendMessage(
        recipients: [Address.parse('+33612345678')],
        body: 'Salut',
      );

      expect(captured?.arguments['recipients'], ['+33612345678']);
      expect(captured?.arguments['body'], 'Salut');
      expect(sent.status, MessageStatus.sending);
    });

    test('traduit les codes d\'erreur natifs en exceptions métier', () async {
      Future<void> expectError(String code, Matcher matcher) async {
        mock({
          'markThreadRead': (_) => throw PlatformException(code: code),
        });
        await expectLater(channel.markThreadRead('42'), throwsA(matcher));
      }

      await expectError('not_default_sms_app', isA<NotDefaultSmsAppException>());
      await expectError('permission_denied', isA<SmsPermissionDeniedException>());
      await expectError('not_found', isA<MessageNotFoundException>());
      await expectError('boom', isA<MessageSendFailedException>());
    });

    test('traduit l\'état des autorisations', () async {
      mock({
        'checkAccess': (_) => {
          'canReadSms': true,
          'canSendSms': true,
          'canReadContacts': false,
          'canNotify': false,
          'isDefaultSmsApp': false,
        },
      });

      final access = await channel.checkAccess();

      expect(access.canBrowse, isTrue);
      expect(access.canCompose, isFalse);
      expect(access.canReadContacts, isFalse);
      expect(access.canNotify, isFalse);
    });

    test('pousse les fils en sourdine et l\'annuaire au natif', () async {
      final calls = <String, Object?>{};
      mock({
        'setMutedThreads': (call) => calls['muted'] = call.arguments['threadIds'],
        'setNotificationDirectory': (call) => calls['names'] = call.arguments['names'],
      });

      await channel.setMutedThreads({'42'});
      await channel.setNotificationDirectory({'612345678': 'Camille'});

      expect(calls['muted'], ['42']);
      expect(calls['names'], {'612345678': 'Camille'});
    });

    test('consomme la demande de rédaction du lancement', () async {
      mock({
        'consumeLaunchRequest': (_) => {
          'address': '+33612345678',
          'body': 'Bonjour',
        },
      });

      final request = await channel.consumeLaunchRequest();

      expect(request?.recipient, Address.parse('0612345678'));
      expect(request?.body, 'Bonjour');
    });

    test('une demande vide est ignorée', () async {
      mock({'consumeLaunchRequest': (_) => <String, Object?>{}});

      expect(await channel.consumeLaunchRequest(), isNull);
    });
  });
}
