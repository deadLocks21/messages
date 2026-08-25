/// Sens d'un message vis-à-vis de l'utilisateur.
///
/// Correspond aux « boîtes » du stock Telephony : `inbox`/`received` pour
/// l'entrant, `sent`/`outbox`/`failed` pour le sortant.
enum MessageDirection {
  incoming,
  outgoing;

  bool get isOutgoing => this == MessageDirection.outgoing;

  String get wire => name;
  static MessageDirection fromWire(String? w) =>
      MessageDirection.values.where((e) => e.name == w).firstOrNull ??
      MessageDirection.incoming;
}

/// Cycle de vie d'un message. `sending` → `sent` → `delivered`, ou `failed`.
/// Un entrant est toujours `received`.
enum MessageStatus {
  sending,
  sent,
  delivered,
  failed,
  received;

  bool get isPending => this == MessageStatus.sending;
  bool get hasFailed => this == MessageStatus.failed;

  String get wire => name;
  static MessageStatus fromWire(String? w) =>
      MessageStatus.values.where((e) => e.name == w).firstOrNull ??
      MessageStatus.received;
}

/// Onglet de la liste des conversations (Google Messages : « Tous » /
/// « Non lus », plus l'écran « Archivées »).
enum ConversationFilter { all, unread, archived }

/// Mode de thème choisi par l'utilisateur (persisté). Mappé vers `ThemeMode`
/// Flutter par `AppThemeData.toFlutterThemeMode`.
enum AppThemeMode {
  light,
  dark,
  system;

  static AppThemeMode fromName(String? name) =>
      AppThemeMode.values.where((m) => m.name == name).firstOrNull ??
      AppThemeMode.system;
}
