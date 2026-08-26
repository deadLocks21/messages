// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sms_access.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// État courant des autorisations SMS. `keepAlive` : c'est lui qui pilote la
/// redirection du routeur, il doit survivre aux écrans.
///
/// Relu à chaque retour au premier plan (`MessagesApp`), parce que
/// l'utilisateur peut avoir changé l'app SMS par défaut depuis les réglages
/// Android pendant que nous étions en arrière-plan.

@ProviderFor(SmsAccessController)
final smsAccessControllerProvider = SmsAccessControllerProvider._();

/// État courant des autorisations SMS. `keepAlive` : c'est lui qui pilote la
/// redirection du routeur, il doit survivre aux écrans.
///
/// Relu à chaque retour au premier plan (`MessagesApp`), parce que
/// l'utilisateur peut avoir changé l'app SMS par défaut depuis les réglages
/// Android pendant que nous étions en arrière-plan.
final class SmsAccessControllerProvider
    extends $AsyncNotifierProvider<SmsAccessController, SmsAccess> {
  /// État courant des autorisations SMS. `keepAlive` : c'est lui qui pilote la
  /// redirection du routeur, il doit survivre aux écrans.
  ///
  /// Relu à chaque retour au premier plan (`MessagesApp`), parce que
  /// l'utilisateur peut avoir changé l'app SMS par défaut depuis les réglages
  /// Android pendant que nous étions en arrière-plan.
  SmsAccessControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smsAccessControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smsAccessControllerHash();

  @$internal
  @override
  SmsAccessController create() => SmsAccessController();
}

String _$smsAccessControllerHash() =>
    r'477851647073b2c210936b92aea16d2a7300bd7a';

/// État courant des autorisations SMS. `keepAlive` : c'est lui qui pilote la
/// redirection du routeur, il doit survivre aux écrans.
///
/// Relu à chaque retour au premier plan (`MessagesApp`), parce que
/// l'utilisateur peut avoir changé l'app SMS par défaut depuis les réglages
/// Android pendant que nous étions en arrière-plan.

abstract class _$SmsAccessController extends $AsyncNotifier<SmsAccess> {
  FutureOr<SmsAccess> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SmsAccess>, SmsAccess>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SmsAccess>, SmsAccess>,
              AsyncValue<SmsAccess>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
