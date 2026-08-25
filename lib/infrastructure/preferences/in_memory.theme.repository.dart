import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/services/theme.repository.dart';

/// Thème non persisté (tests, web sans stockage).
class InMemoryThemeRepository implements ThemeRepository {
  AppThemeMode _mode;

  InMemoryThemeRepository([this._mode = AppThemeMode.system]);

  @override
  Future<AppThemeMode> get() async => _mode;

  @override
  Future<void> set(AppThemeMode mode) async => _mode = mode;
}
