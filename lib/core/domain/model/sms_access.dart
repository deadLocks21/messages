/// Ce que l'app a le droit de faire avec les SMS, à un instant donné.
///
/// Android sépare deux choses : les **permissions runtime** (lire/envoyer des
/// SMS, lire les contacts) et le **rôle d'application SMS par défaut**. Sans le
/// rôle, une app peut lire le stock mais ni y écrire ni recevoir `SMS_DELIVER`.
class SmsAccess {
  final bool canReadSms;
  final bool canSendSms;
  final bool canReadContacts;
  final bool isDefaultSmsApp;

  const SmsAccess({
    required this.canReadSms,
    required this.canSendSms,
    required this.canReadContacts,
    required this.isDefaultSmsApp,
  });

  /// Aucun accès — état initial et valeur de repli hors Android.
  static const none = SmsAccess(
    canReadSms: false,
    canSendSms: false,
    canReadContacts: false,
    isDefaultSmsApp: false,
  );

  /// Accès complet — ce que rend la doublure InMemory.
  static const full = SmsAccess(
    canReadSms: true,
    canSendSms: true,
    canReadContacts: true,
    isDefaultSmsApp: true,
  );

  /// Minimum vital pour afficher quoi que ce soit : sans lecture, l'app n'a
  /// rien à montrer et reste sur l'écran d'accueil.
  bool get canBrowse => canReadSms;

  /// Envoi réellement possible : la permission ne suffit pas, il faut aussi le
  /// rôle par défaut pour écrire dans le stock.
  bool get canCompose => canSendSms && isDefaultSmsApp;

  SmsAccess copyWith({
    bool? canReadSms,
    bool? canSendSms,
    bool? canReadContacts,
    bool? isDefaultSmsApp,
  }) {
    return SmsAccess(
      canReadSms: canReadSms ?? this.canReadSms,
      canSendSms: canSendSms ?? this.canSendSms,
      canReadContacts: canReadContacts ?? this.canReadContacts,
      isDefaultSmsApp: isDefaultSmsApp ?? this.isDefaultSmsApp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsAccess &&
          runtimeType == other.runtimeType &&
          canReadSms == other.canReadSms &&
          canSendSms == other.canSendSms &&
          canReadContacts == other.canReadContacts &&
          isDefaultSmsApp == other.isDefaultSmsApp;

  @override
  int get hashCode =>
      Object.hash(canReadSms, canSendSms, canReadContacts, isDefaultSmsApp);
}
