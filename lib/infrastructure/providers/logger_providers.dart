import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/services/logger.service.dart';
import 'package:messages/infrastructure/logger/app_log_context.dart';
import 'package:messages/infrastructure/logger/composite.logger.service.dart';
import 'package:messages/infrastructure/logger/console.logger.service.dart';
import 'package:messages/infrastructure/logger/platform_info.dart';
import 'package:messages/infrastructure/logger/signoz.logger.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'logger_providers.g.dart';

/// Point d'entrée OTLP/HTTP de Signoz, fixé à la compilation. Vide → Signoz
/// désactivé, et l'app se contente de sa console.
///
/// ```bash
/// flutter run --dart-define=SIGNOZ_INGEST_URL=https://ingest.eu.signoz.cloud:443/v1/logs
/// ```
const String _kSignozEndpoint = String.fromEnvironment('SIGNOZ_INGEST_URL');

/// Clé d'ingestion Signoz Cloud, envoyée en `signoz-access-token`. À laisser
/// vide pour un collecteur auto-hébergé sans authentification.
const String _kSignozKey = String.fromEnvironment('SIGNOZ_INGESTION_KEY');

/// Surcharge éventuelle de `deployment.environment`. Par défaut `production`
/// en build release, `development` sinon.
const String _kEnvOverride = String.fromEnvironment('SIGNOZ_ENV');

/// Version publiée en `service.version`. La CI peut injecter la vraie valeur
/// via `--dart-define=APP_VERSION=$VERSION+$BUILD_NUMBER` ; la sentinelle par
/// défaut rend évident, dans Signoz, un build local non configuré.
const String _kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

/// Décor courant (session, écran, rôle d'app par défaut) recopié sur chaque
/// ligne de log. `keepAlive` : il vit aussi longtemps que le processus.
@Riverpod(keepAlive: true)
AppLogContext appLogContext(Ref ref) =>
    AppLogContext(sessionId: const Uuid().v4());

/// Puits de logs.
///
/// | Mode    | SIGNOZ_INGEST_URL | Implémentation                        |
/// |---------|-------------------|---------------------------------------|
/// | release | absent            | [ConsoleLoggerService] (filet)        |
/// | release | présent           | [SignozLoggerService] seul            |
/// | debug   | absent            | [ConsoleLoggerService] seul           |
/// | debug   | présent           | [CompositeLoggerService] console+signoz|
///
/// La branche debug+signoz est ce qui permet de voir dans sa propre console
/// *exactement* ce qui part sur le réseau — sans elle, calibrer les attributs
/// d'un log revient à deviner puis à attendre qu'ils apparaissent dans Signoz.
///
/// `keepAlive` : l'adaptateur Signoz tient un timer périodique et un client
/// HTTP, qu'il serait absurde de reconstruire à la demande.
@Riverpod(keepAlive: true)
LoggerService loggerService(Ref ref) {
  final hasSignoz = _kSignozEndpoint.isNotEmpty;

  final console = ConsoleLoggerService(
    prefix: hasSignoz && !kReleaseMode ? '[→signoz]' : null,
  );
  if (!hasSignoz) return console;

  final signoz = SignozLoggerService(
    endpoint: _kSignozEndpoint,
    ingestionKey: _kSignozKey.isEmpty ? null : _kSignozKey,
    resourceAttributes: _resourceAttributes(),
  );
  ref.onDispose(signoz.dispose);

  if (kReleaseMode) return signoz;
  return CompositeLoggerService([console, signoz]);
}

/// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.
///
/// Le décor est relu à **chaque** émission (`ref.read`, pas `ref.watch`) :
/// l'instance reste donc stable d'un écran à l'autre — la reconstruire
/// jetterait le tampon Signoz et perdrait les lignes en attente — tout en
/// portant l'écran courant sur la ligne qui vient d'être émise.
@Riverpod(keepAlive: true)
LoggerApplicationService logger(Ref ref) => LoggerApplicationService(
  ref.watch(loggerServiceProvider),
  resolveContext: () => ref.read(appLogContextProvider).snapshot(),
);

Map<String, Object?> _resourceAttributes() => {
  'service.name': 'messages',
  'service.version': _kAppVersion,
  'deployment.environment': _kEnvOverride.isNotEmpty
      ? _kEnvOverride
      : (kReleaseMode ? 'production' : 'development'),
  'os.type': osType(),
  'os.version': osVersion(),
};
