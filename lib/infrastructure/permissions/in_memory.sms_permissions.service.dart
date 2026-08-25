import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/core/domain/services/sms_permissions.service.dart';

/// Autorisations simulées. Par défaut tout est accordé : hors Android, l'app de
/// démonstration doit être utilisable sans écran de permissions.
///
/// Les tests partent de [SmsAccess.none] pour dérouler l'accueil.
class InMemorySmsPermissionsService implements SmsPermissionsService {
  SmsAccess _access;

  /// Ce que rendra la prochaine demande. Permet de simuler un refus.
  final SmsAccess grantedOnRequest;

  InMemorySmsPermissionsService({
    SmsAccess initial = SmsAccess.full,
    SmsAccess? grantedOnRequest,
  }) : _access = initial,
       grantedOnRequest = grantedOnRequest ?? SmsAccess.full;

  @override
  Future<SmsAccess> check() async => _access;

  @override
  Future<SmsAccess> requestPermissions() async {
    _access = _access.copyWith(
      canReadSms: grantedOnRequest.canReadSms,
      canSendSms: grantedOnRequest.canSendSms,
      canReadContacts: grantedOnRequest.canReadContacts,
      canNotify: grantedOnRequest.canNotify,
    );
    return _access;
  }

  /// Nombre d'ouvertures demandées — les tests s'en servent pour vérifier le
  /// repli sur les réglages système.
  int openSettingsCount = 0;

  @override
  Future<void> openSystemSettings() async => openSettingsCount++;

  @override
  Future<SmsAccess> requestDefaultSmsApp() async {
    _access = _access.copyWith(
      isDefaultSmsApp: grantedOnRequest.isDefaultSmsApp,
    );
    return _access;
  }
}
