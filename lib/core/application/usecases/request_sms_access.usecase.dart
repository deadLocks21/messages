import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/core/domain/services/sms_permissions.service.dart';

/// Pilote l'accueil : demander les permissions runtime, puis le rôle
/// d'application SMS par défaut.
///
/// Les deux étapes restent distinctes parce qu'Android les présente
/// séparément — et parce qu'un utilisateur peut très bien accorder les
/// permissions sans céder le rôle (l'app reste alors en lecture seule).
class RequestSmsAccessUseCase {
  final SmsPermissionsService _permissions;

  const RequestSmsAccessUseCase(this._permissions);

  Future<SmsAccess> current() => _permissions.check();

  Future<SmsAccess> requestPermissions() => _permissions.requestPermissions();

  Future<SmsAccess> requestDefaultSmsApp() =>
      _permissions.requestDefaultSmsApp();

  Future<void> openSystemSettings() => _permissions.openSystemSettings();
}
