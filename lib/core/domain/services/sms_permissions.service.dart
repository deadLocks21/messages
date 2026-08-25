import 'package:messages/core/domain/model/sms_access.dart';

/// Port des autorisations : permissions runtime **et** rôle d'application SMS
/// par défaut, qu'Android traite séparément.
abstract interface class SmsPermissionsService {
  /// État courant, sans rien demander à l'utilisateur.
  Future<SmsAccess> check();

  /// Demande les permissions runtime manquantes (SMS + Contacts) et rend
  /// l'état résultant.
  Future<SmsAccess> requestPermissions();

  /// Ouvre la demande de rôle « application SMS par défaut » et rend l'état
  /// résultant une fois la boîte de dialogue fermée.
  Future<SmsAccess> requestDefaultSmsApp();
}
