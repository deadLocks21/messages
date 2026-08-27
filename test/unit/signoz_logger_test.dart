import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/infrastructure/logger/signoz.logger.service.dart';

/// Ce que Signoz reçoit, et rien d'autre.
///
/// La charge OTLP est écrite à la main : c'est le seul endroit du code dont une
/// erreur ne se voit **nulle part** — pas d'exception, pas d'écran cassé,
/// simplement des logs qui n'arrivent jamais. D'où ces tests, qui lisent le
/// corps HTTP réellement posté.
void main() {
  /// Capture les corps postés et rend le statut demandé.
  ({http.Client client, List<Map<String, dynamic>> bodies, List<http.Request> requests})
  recorder({int status = 200}) {
    final bodies = <Map<String, dynamic>>[];
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('', status);
    });
    return (client: client, bodies: bodies, requests: requests);
  }

  SignozLoggerService build(
    http.Client client, {
    String? key,
    Map<String, Object?> resource = const {'service.name': 'messages'},
    int maxBatchSize = 50,
    int maxQueueSize = 500,
  }) => SignozLoggerService(
    endpoint: 'https://ingest.example/v1/logs',
    ingestionKey: key,
    resourceAttributes: resource,
    // Long : c'est `flush()` qui déclenche l'envoi dans les tests, jamais le
    // timer — sinon la fenêtre de course rendrait les assertions instables.
    flushInterval: const Duration(hours: 1),
    maxBatchSize: maxBatchSize,
    maxQueueSize: maxQueueSize,
    client: client,
  );

  Map<String, dynamic> resourceLogOf(Map<String, dynamic> body) =>
      (body['resourceLogs'] as List).single as Map<String, dynamic>;

  List<Map<String, dynamic>> recordsOf(Map<String, dynamic> body) {
    final scope =
        (resourceLogOf(body)['scopeLogs'] as List).single
            as Map<String, dynamic>;
    return (scope['logRecords'] as List).cast<Map<String, dynamic>>();
  }

  Map<String, Object?> resourceAttributesOf(Map<String, dynamic> body) {
    final resource = resourceLogOf(body)['resource'] as Map<String, dynamic>;
    return {
      for (final entry in (resource['attributes'] as List)
          .cast<Map<String, dynamic>>())
        entry['key'] as String:
            (entry['value'] as Map<String, dynamic>).values.single,
    };
  }

  Map<String, Object?> attributesOf(Object? raw) => {
    for (final entry in (raw as List).cast<Map<String, dynamic>>())
      entry['key'] as String:
          (entry['value'] as Map<String, dynamic>).values.single,
  };

  test('un enregistrement part dans la forme OTLP attendue', () async {
    final http_ = recorder();
    final logger = build(http_.client);

    await logger.log(
      LogLevel.warn,
      'message.send_failed',
      attributes: {'recipients.count': 2, 'sms.default_app': false},
    );
    await logger.flush();

    expect(http_.bodies, hasLength(1));
    final record = recordsOf(http_.bodies.single).single;
    expect(record['body'], {'stringValue': 'message.send_failed'});
    // Ce sont ces deux champs que Signoz lit pour classer la ligne : un
    // `severityNumber` erroné range une erreur parmi les infos.
    expect(record['severityText'], 'WARN');
    expect(record['severityNumber'], 13);
    // Le timestamp est en nanosecondes, encodé en chaîne — un entier
    // dépasserait la précision d'un `double` JSON.
    expect(record['timeUnixNano'], isA<String>());
    expect(
      int.parse(record['timeUnixNano'] as String),
      greaterThan(1600000000 * 1000000000),
    );

    expect(attributesOf(record['attributes']), {
      'recipients.count': '2', // intValue est une chaîne en JSON protobuf
      'sms.default_app': false,
    });
  });

  test('les attributs de ressource taguent le lot entier', () async {
    final http_ = recorder();
    final logger = build(
      http_.client,
      resource: {'service.name': 'messages', 'os.type': 'android'},
    );

    await logger.log(LogLevel.info, 'a');
    await logger.log(LogLevel.info, 'b');
    await logger.flush();

    expect(resourceAttributesOf(http_.bodies.single), {
      'service.name': 'messages',
      'os.type': 'android',
    });
    // Un seul POST pour les deux : c'est tout l'intérêt du tampon.
    expect(recordsOf(http_.bodies.single), hasLength(2));
  });

  test('une erreur et sa pile deviennent des attributs `exception.*`', () async {
    final http_ = recorder();
    final logger = build(http_.client);

    await logger.log(
      LogLevel.error,
      'dart.uncaught',
      error: const FormatException('mauvais JSON'),
      stack: StackTrace.fromString('#0 quelquePart'),
    );
    await logger.flush();

    final attrs = attributesOf(
      recordsOf(http_.bodies.single).single['attributes'],
    );
    expect(attrs['exception.type'], 'FormatException');
    expect(attrs['exception.message'], contains('mauvais JSON'));
    expect(attrs['exception.stacktrace'], contains('quelquePart'));
  });

  test('la clé d\'ingestion voyage en en-tête, et seulement si elle existe', () async {
    final withKey = recorder();
    await (build(withKey.client, key: 'secret')
          ..log(LogLevel.info, 'a'))
        .flush();
    expect(withKey.requests.single.headers['signoz-access-token'], 'secret');

    final without = recorder();
    await (build(without.client)..log(LogLevel.info, 'a')).flush();
    expect(without.requests.single.headers, isNot(contains('signoz-access-token')));
  });

  test('le tampon part de lui-même une fois plein', () async {
    final http_ = recorder();
    final logger = build(http_.client, maxBatchSize: 2);

    await logger.log(LogLevel.info, 'a');
    await logger.log(LogLevel.info, 'b');
    // `log` déclenche l'envoi sans l'attendre : on laisse tourner la boucle.
    await Future<void>.delayed(Duration.zero);

    expect(http_.bodies, hasLength(1));
    expect(recordsOf(http_.bodies.single), hasLength(2));
  });

  test('file pleine : les plus vieux sautent, et le trou est annoncé', () async {
    final http_ = recorder();
    // `maxBatchSize` au-delà de la file, pour que rien ne parte tout seul.
    final logger = build(http_.client, maxQueueSize: 2, maxBatchSize: 99);

    await logger.log(LogLevel.info, 'un');
    await logger.log(LogLevel.info, 'deux');
    await logger.log(LogLevel.info, 'trois');
    await logger.flush();

    final records = recordsOf(http_.bodies.single);
    expect(
      records.map((r) => (r['body'] as Map<String, dynamic>)['stringValue']),
      ['deux', 'trois'],
    );
    // Sans ce compteur, un tampon qui déborde se lit comme une app silencieuse.
    expect(
      resourceAttributesOf(http_.bodies.single)['log.dropped_total'],
      '1',
    );
  });

  test('un refus du collecteur ne remonte pas à l\'appelant', () async {
    final http_ = recorder(status: 401);
    final logger = build(http_.client);

    await logger.log(LogLevel.error, 'peu importe');
    // Le contrat de LoggerService : ne jamais lever. Une clé invalide ne doit
    // pas faire tomber l'app qu'elle est censée observer.
    await expectLater(logger.flush(), completes);

    // Et le lot refusé est compté comme perdu, pas rejoué.
    await logger.log(LogLevel.info, 'suivant');
    await logger.flush();
    expect(resourceAttributesOf(http_.bodies.last)['log.dropped_total'], '1');
  });

  test('un réseau absent ne remonte pas non plus', () async {
    final logger = build(
      MockClient((_) => throw const SocketExceptionStub()),
    );

    await logger.log(LogLevel.error, 'peu importe');
    await expectLater(logger.flush(), completes);
  });

  test('une erreur ne fait pas la queue : elle part tout de suite', () async {
    final http_ = recorder();
    // Lot large et timer lointain : seul le niveau peut déclencher l'envoi.
    final logger = build(http_.client, maxBatchSize: 99);

    await logger.log(LogLevel.info, 'app.route');
    await Future<void>.delayed(Duration.zero);
    expect(http_.bodies, isEmpty, reason: 'un info attend son lot');

    await logger.log(LogLevel.error, 'dart.uncaught');
    await Future<void>.delayed(Duration.zero);

    // Une erreur non rattrapée précède souvent de peu un processus qui meurt :
    // dix secondes d'attente suffiraient à la perdre.
    expect(http_.bodies, hasLength(1));
    expect(
      recordsOf(http_.bodies.single).map(
        (r) => (r['body'] as Map<String, dynamic>)['stringValue'],
      ),
      ['app.route', 'dart.uncaught'],
    );
  });

  test('flush() sur un tampon vide ne poste rien', () async {
    final http_ = recorder();
    await build(http_.client).flush();
    expect(http_.bodies, isEmpty);
  });
}

/// Panne réseau simulée. `SocketException` vient de `dart:io`, indisponible
/// pour la cible web sur laquelle ces tests doivent aussi passer.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketExceptionStub: réseau injoignable';
}
