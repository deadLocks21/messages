/// Réglages d'un fil qui n'existent que pour l'app : Android ne stocke ni
/// épinglage, ni archivage, ni sourdine. Persistés côté `shared_preferences`.
class ConversationPreference {
  final String threadId;
  final bool pinned;
  final bool archived;
  final bool muted;

  const ConversationPreference({
    required this.threadId,
    this.pinned = false,
    this.archived = false,
    this.muted = false,
  });

  /// Valeurs par défaut d'un fil jamais touché.
  factory ConversationPreference.none(String threadId) =>
      ConversationPreference(threadId: threadId);

  /// Rien à persister : un fil revenu à son état par défaut est retiré du store.
  bool get isDefault => !pinned && !archived && !muted;

  ConversationPreference copyWith({bool? pinned, bool? archived, bool? muted}) {
    return ConversationPreference(
      threadId: threadId,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      muted: muted ?? this.muted,
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
          muted == other.muted;

  @override
  int get hashCode => Object.hash(threadId, pinned, archived, muted);
}
