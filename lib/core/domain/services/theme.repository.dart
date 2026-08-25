import 'package:messages/core/domain/model/enums.dart';

/// Port de persistance du mode de thème choisi par l'utilisateur.
abstract interface class ThemeRepository {
  Future<AppThemeMode> get();
  Future<void> set(AppThemeMode mode);
}
