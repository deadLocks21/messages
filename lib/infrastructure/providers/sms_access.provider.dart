import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sms_access.provider.g.dart';

/// État courant des autorisations SMS. `keepAlive` : c'est lui qui pilote la
/// redirection du routeur, il doit survivre aux écrans.
///
/// Relu à chaque retour au premier plan (`MessagesApp`), parce que
/// l'utilisateur peut avoir changé l'app SMS par défaut depuis les réglages
/// Android pendant que nous étions en arrière-plan.
@Riverpod(keepAlive: true)
class SmsAccessController extends _$SmsAccessController {
  @override
  Future<SmsAccess> build() => ref.watch(requestSmsAccessUseCaseProvider).current();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(requestSmsAccessUseCaseProvider).current());
  }

  Future<SmsAccess> requestPermissions() async {
    final access = await ref
        .read(requestSmsAccessUseCaseProvider)
        .requestPermissions();
    state = AsyncData(access);
    return access;
  }

  /// Ouvre les réglages système. Utilisé quand une demande de permission ne
  /// produit plus rien (refus définitif).
  Future<void> openSystemSettings() =>
      ref.read(requestSmsAccessUseCaseProvider).openSystemSettings();

  Future<SmsAccess> requestDefaultSmsApp() async {
    final access = await ref
        .read(requestSmsAccessUseCaseProvider)
        .requestDefaultSmsApp();
    state = AsyncData(access);
    return access;
  }
}
