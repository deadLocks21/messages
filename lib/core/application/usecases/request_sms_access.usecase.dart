import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/core/domain/services/sms_permissions.service.dart';

/// Pilote l'accueil : demander les permissions runtime, puis le rôle
/// d'application SMS par défaut.
///
/// Les deux étapes restent distinctes parce qu'Android les présente
/// séparément — et parce qu'un utilisateur peut très bien accorder les
/// permissions sans céder le rôle (l'app reste alors en lecture seule).
///
/// Toutes les demandes sont journalisées avec **leur verdict** : « l'app ne
/// veut pas envoyer » se ramène presque toujours à un rôle refusé ou repris
/// par une autre application, et c'est la seule chose qu'on ne peut pas
/// déduire après coup en regardant le téléphone.
class RequestSmsAccessUseCase {
  final SmsPermissionsService _permissions;
  final LoggerApplicationService _logger;

  const RequestSmsAccessUseCase(
    this._permissions, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  Future<SmsAccess> current() => _permissions.check();

  Future<SmsAccess> requestPermissions() async {
    final access = await _permissions.requestPermissions();
    await _logger.info('sms.permissions_requested', attrs: _attrs(access));
    return access;
  }

  Future<SmsAccess> requestDefaultSmsApp() async {
    final access = await _permissions.requestDefaultSmsApp();
    // Un refus n'est pas une erreur — c'est un choix — mais il condamne l'app
    // à la lecture seule, donc il se voit au niveau `warn`.
    if (access.isDefaultSmsApp) {
      await _logger.info('sms.default_app_granted', attrs: _attrs(access));
    } else {
      await _logger.warn('sms.default_app_refused', attrs: _attrs(access));
    }
    return access;
  }

  Future<void> openSystemSettings() async {
    await _logger.info('sms.system_settings_opened');
    return _permissions.openSystemSettings();
  }

  Map<String, Object?> _attrs(SmsAccess access) => {
    'sms.read': access.canReadSms,
    'sms.send': access.canSendSms,
    'sms.contacts': access.canReadContacts,
    'sms.notify': access.canNotify,
    'sms.default_app': access.isDefaultSmsApp,
  };
}
