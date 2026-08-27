import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/core/domain/services/logger.service.dart';

/// Expédie les enregistrements de log vers une instance Signoz, en OTLP/HTTP.
///
/// Format de fil : la charge JSON `ExportLogsServiceRequest` d'OpenTelemetry,
/// postée sur `<base d'ingestion>/v1/logs`. Signoz accepte nativement
/// l'encodage JSON du protobuf : un corps écrit à la main est plus léger que
/// `opentelemetry` + `opentelemetry_exporter_otlp_http`, encore rugueux côté
/// Dart, pour un besoin qui tient en trente lignes de sérialisation.
///
/// ## Attributs de ressource
///
/// Chaque lot est tagué des [resourceAttributes] passés à la construction
/// (`service.name`, `service.version`, `service.instance.id`,
/// `deployment.environment`, `os.type`…). Ils apparaissent en colonnes
/// `resource.*` dans Signoz et sont la bonne façon de découper un tableau de
/// bord.
///
/// ## Tampon
///
/// Les enregistrements s'accumulent en mémoire et partent :
/// - dès que [maxBatchSize] est atteint ;
/// - sinon toutes les [flushInterval], par un timer périodique ;
/// - sur [flush] explicite — appelé quand l'app passe en arrière-plan.
///
/// La liste est plafonnée à [maxQueueSize] pour ne pas grossir sans fin quand
/// le réseau reste absent : ce sont les **plus vieux** qui sautent, le récent
/// étant plus utile que l'ancien.
///
/// ## En cas d'échec
///
/// Un lot qui ne part pas est **perdu**, pas rejoué : la télémétrie est au
/// mieux-effort, et une file de reprise finirait par empiler des doublons au
/// premier incident réseau. L'échec est signalé dans la console de dev via
/// `dart:developer` — surtout pas via [LoggerService], qui bouclerait.
///
/// Un statut HTTP non-2xx est traité comme un échec et **journalisé avec le
/// corps de la réponse** : c'est le seul moyen de voir une clé d'ingestion
/// invalide, qui autrement se traduirait par un silence parfait côté Signoz.
///
/// ## Les erreurs ne font pas la queue
///
/// Un enregistrement de niveau `error` déclenche une expédition immédiate,
/// sans attendre le lot ni le timer. C'est le seul niveau dont on sait qu'il
/// peut être la **dernière** chose que l'app dira : une erreur non rattrapée
/// précède souvent de peu un processus qui meurt ou un utilisateur qui balaie
/// l'app, et dix secondes d'attente suffisent à la perdre. Les envois
/// concurrents se fondent en un seul (`_inflight`), une rafale d'erreurs ne
/// produit donc pas une rafale de requêtes.
class SignozLoggerService implements LoggerService {
  /// Point d'entrée OTLP/HTTP complet, p. ex.
  /// `https://ingest.eu.signoz.cloud:443/v1/logs` (Signoz Cloud) ou
  /// `http://10.0.2.2:4318/v1/logs` (émulateur Android → collecteur
  /// auto-hébergé sur la machine hôte).
  final String endpoint;

  /// Clé d'ingestion Signoz Cloud, envoyée en en-tête `signoz-access-token`.
  /// `null` ou vide pour un déploiement auto-hébergé sans authentification.
  final String? ingestionKey;

  /// Attributs de ressource OTLP attachés à chaque lot.
  final Map<String, Object?> resourceAttributes;

  final Duration flushInterval;
  final int maxBatchSize;
  final int maxQueueSize;

  final http.Client _client;
  final bool _ownsClient;

  final List<_PendingRecord> _buffer = [];
  Timer? _timer;
  bool _disposed = false;
  Future<void>? _inflight;

  /// Nombre d'enregistrements jetés faute de place ou faute de réseau, depuis
  /// le démarrage. Publié dans le lot suivant : un trou dans les logs qu'on
  /// sait mesurer vaut mieux qu'un trou qu'on ne voit pas.
  int _dropped = 0;

  SignozLoggerService({
    required this.endpoint,
    this.ingestionKey,
    this.resourceAttributes = const {},
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 50,
    this.maxQueueSize = 500,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    if (_disposed) return;
    if (_buffer.length >= maxQueueSize) {
      _buffer.removeAt(0);
      _dropped++;
    }
    _buffer.add(
      _PendingRecord(
        timestampNanos: _nowUnixNano(),
        level: level,
        message: message,
        attributes: attributes,
        error: error,
        stack: stack,
      ),
    );
    // Le lot plein, ou une erreur — voir « Les erreurs ne font pas la queue ».
    if (_buffer.length >= maxBatchSize || level == LogLevel.error) {
      unawaited(flush());
    }
  }

  @override
  Future<void> flush() async {
    // Un seul envoi à la fois : les enregistrements arrivés entre-temps
    // restent au tampon et partiront au tour suivant.
    final inflight = _inflight;
    if (inflight != null) return inflight;
    if (_buffer.isEmpty) return;

    final batch = List<_PendingRecord>.from(_buffer);
    _buffer.clear();
    final future = _ship(batch);
    _inflight = future;
    try {
      await future;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _ship(List<_PendingRecord> batch) async {
    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'content-type': 'application/json',
              if (ingestionKey != null && ingestionKey!.isNotEmpty)
                'signoz-access-token': ingestionKey!,
            },
            body: jsonEncode(_buildPayload(batch)),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _dropped += batch.length;
        _complain(
          'signoz: lot de ${batch.length} refusé '
          '(HTTP ${response.statusCode}) — abandonné',
          error: _truncate(response.body),
        );
      }
    } catch (e, st) {
      _dropped += batch.length;
      _complain(
        'signoz: lot de ${batch.length} non expédié — abandonné',
        error: e,
        stack: st,
      );
    }
  }

  /// Se plaint dans la console de dev. Jamais via [LoggerService] : le logger
  /// qui journalise ses propres pannes s'auto-alimente.
  void _complain(String message, {Object? error, StackTrace? stack}) {
    developer.log(
      message,
      name: 'messages.logger',
      level: LogLevel.warn.otelSeverityNumber * 100,
      error: error,
      stackTrace: stack,
    );
  }

  Map<String, dynamic> _buildPayload(List<_PendingRecord> batch) {
    final dropped = _dropped;
    return {
      'resourceLogs': [
        {
          'resource': {
            'attributes': _otlpAttributes({
              ...resourceAttributes,
              // Compté depuis le démarrage : une valeur qui grimpe dit
              // « il manque des lignes », ce qu'aucune requête sur les
              // lignes présentes ne pourrait dire.
              if (dropped > 0) 'log.dropped_total': dropped,
            }),
          },
          'scopeLogs': [
            {
              'scope': {'name': 'messages.app'},
              'logRecords': batch.map(_otlpRecord).toList(growable: false),
            },
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _otlpRecord(_PendingRecord r) {
    final attrs = <String, Object?>{...r.attributes};
    if (r.error != null) {
      attrs['exception.type'] = r.error.runtimeType.toString();
      attrs['exception.message'] = r.error.toString();
    }
    if (r.stack != null) {
      attrs['exception.stacktrace'] = _truncate(r.stack.toString());
    }
    return {
      'timeUnixNano': r.timestampNanos.toString(),
      'severityNumber': r.level.otelSeverityNumber,
      'severityText': r.level.otelSeverityText,
      'body': {'stringValue': r.message},
      'attributes': _otlpAttributes(attrs),
    };
  }

  /// Encode une map plate dans la forme `KeyValue[]` attendue par OTLP.
  ///
  /// Les types inconnus sont convertis par `toString()` plutôt que jetés :
  /// l'appelant voit toujours *quelque chose* dans Signoz.
  List<Map<String, dynamic>> _otlpAttributes(Map<String, Object?> map) {
    final out = <Map<String, dynamic>>[];
    for (final e in map.entries) {
      final value = e.value;
      final Map<String, dynamic> wrapped;
      if (value == null) {
        // OTLP n'a pas de null : la chaîne vide garde au moins la clé
        // indexée.
        wrapped = {'stringValue': ''};
      } else if (value is String) {
        wrapped = {'stringValue': value};
      } else if (value is bool) {
        wrapped = {'boolValue': value};
      } else if (value is int) {
        wrapped = {'intValue': value.toString()};
      } else if (value is double) {
        wrapped = {'doubleValue': value};
      } else {
        wrapped = {'stringValue': value.toString()};
      }
      out.add({'key': e.key, 'value': wrapped});
    }
    return out;
  }

  /// Une stacktrace Flutter fait facilement plusieurs kilo-octets, et le
  /// collecteur refuse les corps démesurés. On garde la tête, qui porte le
  /// site d'erreur.
  static String _truncate(String value, {int max = 4000}) =>
      value.length <= max ? value : '${value.substring(0, max)}… [tronqué]';

  int _nowUnixNano() => DateTime.now().microsecondsSinceEpoch * 1000;

  /// Arrête le timer et expédie ce qui reste. Appelé à la destruction du
  /// provider (et par les tests).
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await flush();
    _disposed = true;
    if (_ownsClient) _client.close();
  }
}

class _PendingRecord {
  final int timestampNanos;
  final LogLevel level;
  final String message;
  final Map<String, Object?> attributes;
  final Object? error;
  final StackTrace? stack;

  _PendingRecord({
    required this.timestampNanos,
    required this.level,
    required this.message,
    required this.attributes,
    this.error,
    this.stack,
  });
}
