import 'package:messages/core/domain/model/log_level.dart';

/// Contrat d'émission des enregistrements de log.
///
/// Port domaine de la préoccupation « logging ». Les implémentations vivent
/// dans `lib/infrastructure/logger/` :
///
/// - `ConsoleLoggerService`   — écrit dans la console de dev.
/// - `CompositeLoggerService` — diffuse vers plusieurs services à la fois.
/// - `InMemoryLoggerService`  — capture les enregistrements pour les tests.
///
/// Le contrat est volontairement minuscule : un seul puits asynchrone. Les
/// commodités (`info`, `error`, attributs de contexte…) vivent dans la couche
/// application (`LoggerApplicationService`) pour que le port reste stable d'une
/// implémentation à l'autre.
///
/// Les implémentations NE DOIVENT PAS lever d'exception : un logger qui échoue
/// doit se dégrader silencieusement.
abstract interface class LoggerService {
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes,
    Object? error,
    StackTrace? stack,
  });

  /// Vide le tampon en cours. No-op pour les adaptateurs sans tampon.
  Future<void> flush();
}
