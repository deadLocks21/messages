import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/core/domain/services/logger.service.dart';

/// [LoggerService] de test qui enregistre chaque entrée dans une liste en
/// mémoire. Calqué sur le motif `InMemory*Repository` utilisé ailleurs dans
/// `lib/infrastructure/`.
///
/// Non câblé dans le provider de production — les tests qui ont besoin
/// d'asserter sur les logs le construisent directement :
///
/// ```dart
/// final logger = InMemoryLoggerService();
/// await monUsecase.run();
/// expect(logger.records.last.message, equals('sync.started'));
/// ```
class InMemoryLoggerService implements LoggerService {
  final List<LoggedRecord> records = [];

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    records.add(
      LoggedRecord(
        level: level,
        message: message,
        attributes: Map.unmodifiable(attributes),
        error: error,
        stack: stack,
      ),
    );
  }

  @override
  Future<void> flush() async {}

  /// Jette toutes les entrées enregistrées. Utile entre deux cas de test.
  void clear() => records.clear();
}

/// Une entrée de log capturée par [InMemoryLoggerService].
class LoggedRecord {
  final LogLevel level;
  final String message;
  final Map<String, Object?> attributes;
  final Object? error;
  final StackTrace? stack;

  const LoggedRecord({
    required this.level,
    required this.message,
    required this.attributes,
    this.error,
    this.stack,
  });
}
