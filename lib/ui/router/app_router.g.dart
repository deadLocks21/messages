// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Router unique. Le `redirect` est piloté par l'accès aux SMS : sans droit de
/// lecture, il n'y a rien à afficher d'autre que l'écran d'accueil.

@ProviderFor(goRouter)
final goRouterProvider = GoRouterProvider._();

/// Router unique. Le `redirect` est piloté par l'accès aux SMS : sans droit de
/// lecture, il n'y a rien à afficher d'autre que l'écran d'accueil.

final class GoRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Router unique. Le `redirect` est piloté par l'accès aux SMS : sans droit de
  /// lecture, il n'y a rien à afficher d'autre que l'écran d'accueil.
  GoRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'goRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$goRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return goRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$goRouterHash() => r'50edd7e6f3cc5c4f202e1e447cc541e93e6135e8';
