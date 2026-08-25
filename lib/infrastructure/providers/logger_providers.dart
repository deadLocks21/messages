import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/services/logger.service.dart';
import 'package:messages/infrastructure/logger/console.logger.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger_providers.g.dart';

/// Puits de logs. Un seul adaptateur pour l'instant ; en ajouter un (capture en
/// mémoire pour un écran de diagnostic, export distant) se fait ici en
/// emballant les deux dans un `CompositeLoggerService`.
@Riverpod(keepAlive: true)
LoggerService loggerService(Ref ref) => const ConsoleLoggerService();

/// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.
@Riverpod(keepAlive: true)
LoggerApplicationService logger(Ref ref) =>
    LoggerApplicationService(ref.watch(loggerServiceProvider));
