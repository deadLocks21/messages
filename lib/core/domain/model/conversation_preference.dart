/// Réglages d'un fil qui n'existent que pour l'app : Android ne stocke ni
/// épinglage, ni archivage, ni sourdine. Persistés côté `shared_preferences`.
class ConversationPreference {
  final String threadId;
  final bool pinned;
  final bool archived;

  /// Sourdine sans échéance — la « Toujours » du dialogue de mise en veille.
  final bool muted;

  /// Mise en veille jusqu'à une date. `null` quand il n'y en a pas.
  ///
  /// Distincte de [muted] parce qu'elle **expire toute seule**, y compris
  /// pendant que l'app est fermée : c'est une date qu'on publie à la
  /// plateforme, pas un booléen qu'il faudrait penser à retourner.
  final DateTime? snoozedUntil;

  const ConversationPreference({
    required this.threadId,
    this.pinned = false,
    this.archived = false,
    this.muted = false,
    this.snoozedUntil,
  });

  /// Valeurs par défaut d'un fil jamais touché.
  factory ConversationPreference.none(String threadId) =>
      ConversationPreference(threadId: threadId);

  /// Rien à persister : un fil revenu à son état par défaut est retiré du store.
  bool get isDefault => !pinned && !archived && !muted && snoozedUntil == null;

  /// Ce fil notifie-t-il, à cet instant ? Une veille échue ne compte plus,
  /// sans qu'on ait eu à la nettoyer.
  bool isSilencedAt(DateTime now) =>
      muted || (snoozedUntil?.isAfter(now) ?? false);

  /// [clearSnooze] plutôt qu'un `snoozedUntil: null` : en Dart, un paramètre
  /// nommé absent et un paramètre nommé `null` sont indiscernables, et il faut
  /// bien pouvoir réveiller un fil.
  ConversationPreference copyWith({
    bool? pinned,
    bool? archived,
    bool? muted,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) {
    return ConversationPreference(
      threadId: threadId,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      muted: muted ?? this.muted,
      snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationPreference &&
          runtimeType == other.runtimeType &&
          threadId == other.threadId &&
          pinned == other.pinned &&
          archived == other.archived &&
          muted == other.muted &&
          snoozedUntil == other.snoozedUntil;

  @override
  int get hashCode =>
      Object.hash(threadId, pinned, archived, muted, snoozedUntil);
}
