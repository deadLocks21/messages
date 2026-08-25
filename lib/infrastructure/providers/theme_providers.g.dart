// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Mode de thème (clair/sombre/système), persisté derrière son port.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Mode de thème (clair/sombre/système), persisté derrière son port.
final class ThemeModeControllerProvider
    extends $AsyncNotifierProvider<ThemeModeController, AppThemeMode> {
  /// Mode de thème (clair/sombre/système), persisté derrière son port.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();
}

String _$themeModeControllerHash() =>
    r'2555c0b5f1758872067e18809758cfb0b626d401';

/// Mode de thème (clair/sombre/système), persisté derrière son port.

abstract class _$ThemeModeController extends $AsyncNotifier<AppThemeMode> {
  FutureOr<AppThemeMode> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppThemeMode>, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppThemeMode>, AppThemeMode>,
              AsyncValue<AppThemeMode>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
