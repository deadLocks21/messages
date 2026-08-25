import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_providers.g.dart';

/// Mode de thème (clair/sombre/système), persisté derrière son port.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  Future<AppThemeMode> build() => ref.watch(themeRepositoryProvider).get();

  Future<void> set(AppThemeMode mode) async {
    await ref.read(themeRepositoryProvider).set(mode);
    state = AsyncData(mode);
  }
}
