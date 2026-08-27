/// Où en est la lecture d'une pièce jointe sonore.
///
/// Valeur immuable, republiée à chaque avancée : c'est tout ce dont une bulle a
/// besoin pour se peindre, et rien de plus — ni le lecteur, ni les octets.
class AudioPlayback {
  /// Pièce jointe en cours, ou `null` quand rien ne joue.
  final String? attachmentId;

  final Duration position;

  /// Durée totale, `Duration.zero` tant qu'elle n'est pas connue : un son ne se
  /// mesure qu'une fois ouvert, et une partie de MMS peut n'annoncer aucune
  /// durée.
  final Duration duration;

  /// Faux pendant une pause : la pièce jointe reste celle-là, à sa position.
  final bool isPlaying;

  const AudioPlayback({
    required this.attachmentId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
  });

  /// Rien en cours. C'est aussi l'état d'arrivée : une lecture qui va au bout
  /// ne laisse pas la bulle figée sur sa dernière image.
  static const idle = AudioPlayback(attachmentId: null);

  bool isFor(String id) => attachmentId == id;

  /// Avancement entre 0 et 1. Sans durée connue, rien n'a avancé.
  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  AudioPlayback copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
  }) => AudioPlayback(
    attachmentId: attachmentId,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    isPlaying: isPlaying ?? this.isPlaying,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPlayback &&
          runtimeType == other.runtimeType &&
          attachmentId == other.attachmentId &&
          position == other.position &&
          duration == other.duration &&
          isPlaying == other.isPlaying;

  @override
  int get hashCode =>
      Object.hash(attachmentId, position, duration, isPlaying);
}
