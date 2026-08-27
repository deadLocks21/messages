import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/infrastructure/attachments/android.mms_configuration.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';
import '../helpers/test_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('fr.dtfh.messages/sms');
  late int calls;
  Object? reply;

  /// Le canal natif, simulé : c'est le seul moyen de compter les allers-retours
  /// que le cache est censé éviter.
  void stub(Object? value) {
    reply = value;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'mmsMaxMessageSize') return null;
          calls++;
          if (reply is Exception) {
            throw PlatformException(code: 'sms_error', message: 'indisponible');
          }
          return reply;
        });
  }

  setUp(() => calls = 0);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  AndroidMmsConfiguration configuration() =>
      AndroidMmsConfiguration(
        const AndroidSmsChannel(),
        logger: testLogger(),
      );

  group('AndroidMmsConfiguration', () {
    test('lit la limite de l\'opérateur', () async {
      stub(1024 * 1024);

      expect((await configuration().limits()).maxTotalBytes, 1024 * 1024);
    });

    test('ne consulte le système qu\'une fois', () async {
      stub(1024 * 1024);
      final config = configuration();

      for (var i = 0; i < 5; i++) {
        await config.limits();
      }

      expect(calls, 1);
    });

    test('les appels simultanés partagent une seule lecture', () async {
      stub(1024 * 1024);
      final config = configuration();

      await Future.wait([
        config.limits(),
        config.limits(),
        config.limits(),
      ]);

      expect(calls, 1);
    });

    test('relit après invalidation', () async {
      stub(1024 * 1024);
      final config = configuration();

      await config.limits();
      config.invalidate();
      await config.limits();

      expect(calls, 2);
    });

    test('un échec n\'est pas mis en cache', () async {
      // Au démarrage la configuration opérateur peut n'être pas encore
      // résolue : figer ce demi-échec condamnerait la session à comprimer plus
      // que nécessaire.
      stub(Exception());
      final config = configuration();

      expect(await config.limits(), MmsLimits.fallback);
      expect(await config.limits(), MmsLimits.fallback);
      expect(calls, 2);
    });

    test('une valeur absente n\'est pas mise en cache non plus', () async {
      stub(null);
      final config = configuration();

      expect(await config.limits(), MmsLimits.fallback);
      await config.limits();

      expect(calls, 2);
    });
  });
}
