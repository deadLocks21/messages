import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
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
  Future<SmsAccess> build() async =>
      _publish(await ref.watch(requestSmsAccessUseCaseProvider).current());

  Future<void> refresh() async {
    final before = state.value;
    final access = _publish(
      await ref.read(requestSmsAccessUseCaseProvider).current(),
    );
    // Le rôle peut avoir changé pendant qu'on était en arrière-plan, sans que
    // l'app en soit prévenue : une autre application SMS installée entre-temps
    // le lui reprend. C'est la première explication d'une app soudain devenue
    // muette, et rien d'autre ne l'enregistre.
    if (before != null && before.isDefaultSmsApp != access.isDefaultSmsApp) {
      await ref.read(loggerProvider).warn(
        'sms.default_app_changed',
        attrs: {'sms.default_app': access.isDefaultSmsApp},
      );
    }
    state = AsyncData(access);
  }

  /// Recopie l'état du rôle dans le décor des logs : chaque ligne émise
  /// ensuite portera `sms.default_app`, et la moitié des échecs d'écriture
  /// s'expliqueront d'eux-mêmes.
  SmsAccess _publish(SmsAccess access) {
    ref.read(appLogContextProvider).isDefaultSmsApp = access.isDefaultSmsApp;
    return access;
  }

  Future<SmsAccess> requestPermissions() async {
    final access = _publish(
      await ref.read(requestSmsAccessUseCaseProvider).requestPermissions(),
    );
    // Le carnet lu avant l'accord était vide : le garder en mémoire
    // condamnerait l'app à n'afficher que des numéros.
    ref.read(contactDirectoryServiceProvider).invalidate();
    state = AsyncData(access);
    return access;
  }

  /// Ouvre les réglages système. Utilisé quand une demande de permission ne
  /// produit plus rien (refus définitif).
  Future<void> openSystemSettings() =>
      ref.read(requestSmsAccessUseCaseProvider).openSystemSettings();

  Future<SmsAccess> requestDefaultSmsApp() async {
    final access = _publish(
      await ref.read(requestSmsAccessUseCaseProvider).requestDefaultSmsApp(),
    );
    state = AsyncData(access);
    return access;
  }
}
