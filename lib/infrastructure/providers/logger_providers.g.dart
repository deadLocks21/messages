// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Puits de logs. Un seul adaptateur pour l'instant ; en ajouter un (capture en
/// mémoire pour un écran de diagnostic, export distant) se fait ici en
/// emballant les deux dans un `CompositeLoggerService`.

@ProviderFor(loggerService)
final loggerServiceProvider = LoggerServiceProvider._();

/// Puits de logs. Un seul adaptateur pour l'instant ; en ajouter un (capture en
/// mémoire pour un écran de diagnostic, export distant) se fait ici en
/// emballant les deux dans un `CompositeLoggerService`.

final class LoggerServiceProvider
    extends $FunctionalProvider<LoggerService, LoggerService, LoggerService>
    with $Provider<LoggerService> {
  /// Puits de logs. Un seul adaptateur pour l'instant ; en ajouter un (capture en
  /// mémoire pour un écran de diagnostic, export distant) se fait ici en
  /// emballant les deux dans un `CompositeLoggerService`.
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

String _$loggerServiceHash() => r'f8676e39a0224a2b7e2b63cfc598a5440878b7c3';

/// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.

@ProviderFor(logger)
final loggerProvider = LoggerProvider._();

/// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.

final class LoggerProvider
    extends
        $FunctionalProvider<
          LoggerApplicationService,
          LoggerApplicationService,
          LoggerApplicationService
        >
    with $Provider<LoggerApplicationService> {
  /// Façade utilisée partout ailleurs : `ref.read(loggerProvider).info(...)`.
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

String _$loggerHash() => r'8f327c64c437b482fdd376531f097903b5b60201';
