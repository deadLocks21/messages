import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/infrastructure/logger/in_memory.logger.service.dart';

/// Le logger des tests : capture tout, n'écrit nulle part.
///
/// Les services et cas d'usage réclament un logger parce qu'en production
/// personne ne doit pouvoir en construire un sans puits — mais un test n'a
/// aucune raison de polluer sa sortie. Passer [sink] permet en plus d'asserter
/// sur ce qui a été journalisé :
///
/// ```dart
/// final sink = InMemoryLoggerService();
/// await usecase.execute(...);
/// expect(sink.records.last.message, 'message.send');
/// ```
LoggerApplicationService testLogger([InMemoryLoggerService? sink]) =>
    LoggerApplicationService(sink ?? InMemoryLoggerService());
