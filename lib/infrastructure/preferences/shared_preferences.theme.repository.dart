import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/services/theme.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode de thème persisté dans `shared_preferences`.
class SharedPreferencesThemeRepository implements ThemeRepository {
  static const _key = 'messages.theme_mode';

  @override
  Future<AppThemeMode> get() async =>
      AppThemeMode.fromName((await SharedPreferences.getInstance()).getString(_key));

  @override
  Future<void> set(AppThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(_key, mode.name);
  }
}
