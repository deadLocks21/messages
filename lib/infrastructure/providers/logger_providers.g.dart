// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Décor courant (session, écran, rôle d'app par défaut) recopié sur chaque
/// ligne de log. `keepAlive` : il vit aussi longtemps que le processus.

@ProviderFor(appLogContext)
final appLogContextProvider = AppLogContextProvider._();

/// Décor courant (session, écran, rôle d'app par défaut) recopié sur chaque
/// ligne de log. `keepAlive` : il vit aussi longtemps que le processus.

final class AppLogContextProvider
    extends $FunctionalProvider<AppLogContext, AppLogContext, AppLogContext>
    with $Provider<AppLogContext> {
  /// Décor courant (session, écran, rôle d'app par défaut) recopié sur chaque
  /// ligne de log. `keepAlive` : il vit aussi longtemps que le processus.
  AppLogContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLogContextProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLogContextHash();

  @$internal
  @override
  $ProviderElement<AppLogContext> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLogContext create(Ref ref) {
    return appLogContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLogContext value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLogContext>(value),
    );
  }
}

String _$appLogContextHash() => r'e0e224e979cfd3abcf59c2a400b17a929c745d6f';

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

@ProviderFor(loggerService)
final loggerServiceProvider = LoggerServiceProvider._();

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

final class LoggerServiceProvider
    extends $FunctionalProvider<LoggerService, LoggerService, LoggerService>
    with $Provider<LoggerService> {
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
  LoggerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerServiceHash();

  @$internal
  @override
  $ProviderElement<LoggerService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoggerService create(Ref ref) {
    return loggerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoggerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoggerService>(value),
    );
  }
}

String _$loggerServiceHash() => r'210de394e836fb5fa607addcf6994e3b1daa85a8';

/// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.
///
/// Le décor est relu à **chaque** émission (`ref.read`, pas `ref.watch`) :
/// l'instance reste donc stable d'un écran à l'autre — la reconstruire
/// jetterait le tampon Signoz et perdrait les lignes en attente — tout en
/// portant l'écran courant sur la ligne qui vient d'être émise.

@ProviderFor(logger)
final loggerProvider = LoggerProvider._();

/// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.
///
/// Le décor est relu à **chaque** émission (`ref.read`, pas `ref.watch`) :
/// l'instance reste donc stable d'un écran à l'autre — la reconstruire
/// jetterait le tampon Signoz et perdrait les lignes en attente — tout en
/// portant l'écran courant sur la ligne qui vient d'être émise.

final class LoggerProvider
    extends
        $FunctionalProvider<
          LoggerApplicationService,
          LoggerApplicationService,
          LoggerApplicationService
        >
    with $Provider<LoggerApplicationService> {
  /// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.
  ///
  /// Le décor est relu à **chaque** émission (`ref.read`, pas `ref.watch`) :
  /// l'instance reste donc stable d'un écran à l'autre — la reconstruire
  /// jetterait le tampon Signoz et perdrait les lignes en attente — tout en
  /// portant l'écran courant sur la ligne qui vient d'être émise.
  LoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerHash();

  @$internal
  @override
  $ProviderElement<LoggerApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LoggerApplicationService create(Ref ref) {
    return logger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoggerApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoggerApplicationService>(value),
    );
  }
}

String _$loggerHash() => r'510bf01aa0e6818c9f313e1e9b6e9adc94d64b60';
