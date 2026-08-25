import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/core/domain/services/sms_permissions.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';
import 'package:permission_handler/permission_handler.dart';

/// Autorisations réelles : `permission_handler` pour les permissions runtime,
/// canal natif pour le rôle d'application SMS par défaut (`RoleManager`).
///
/// Les deux sources sont fusionnées en un seul [SmsAccess] : c'est la seule
/// chose que le reste de l'app manipule.
class PermissionHandlerSmsPermissionsService implements SmsPermissionsService {
  final AndroidSmsChannel _channel;

  const PermissionHandlerSmsPermissionsService(this._channel);

  @override
  Future<SmsAccess> check() async => _merge(
    sms: await Permission.sms.isGranted,
    contacts: await Permission.contacts.isGranted,
  );

  @override
  Future<SmsAccess> requestPermissions() async {
    final statuses = await [Permission.sms, Permission.contacts].request();
    return _merge(
      sms: statuses[Permission.sms]?.isGranted ?? false,
      contacts: statuses[Permission.contacts]?.isGranted ?? false,
    );
  }

  @override
  Future<SmsAccess> requestDefaultSmsApp() async {
    // Le natif rend l'état complet après fermeture de la boîte de dialogue de
    // rôle ; les permissions runtime, elles, n'ont pas bougé.
    final afterRole = await _channel.requestDefaultSmsApp();
    final current = await check();
    return current.copyWith(isDefaultSmsApp: afterRole.isDefaultSmsApp);
  }

  /// `Permission.sms` couvre `READ_SMS`, `SEND_SMS` et `RECEIVE_SMS` : Android
  /// les regroupe dans le même groupe de permissions, il n'y a donc qu'un seul
  /// verdict à propager aux deux drapeaux.
  Future<SmsAccess> _merge({required bool sms, required bool contacts}) async {
    final native = await _channel.checkAccess();
    return SmsAccess(
      canReadSms: sms,
      canSendSms: sms,
      canReadContacts: contacts,
      isDefaultSmsApp: native.isDefaultSmsApp,
    );
  }
}
