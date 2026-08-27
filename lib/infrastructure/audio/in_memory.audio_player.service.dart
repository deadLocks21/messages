import 'dart:async';

import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/core/domain/services/audio_player.service.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

/// [AudioPlayerService] simulé : il n'émet aucun son, il avance.
///
/// Hors Android il n'y a pas de lecteur, et les tests n'en veulent pas : ce
/// qu'on vérifie d'un vocal, c'est que la bulle bascule en pause, que le
/// curseur avance et qu'un second vocal arrête le premier. Cette doublure
/// reproduit exactement ce comportement-là, à la milliseconde près, avec un
/// simple minuteur.
class InMemoryAudioPlayerService implements AudioPlayerService {
  final InMemorySmsStore _store;

  final StreamController<AudioPlayback> _events =
      StreamController<AudioPlayback>.broadcast();

  AudioPlayback _state = AudioPlayback.idle;
  Timer? _ticker;

  /// Pas d'avancée. Assez fin pour que le curseur glisse, assez large pour ne
  /// pas repeindre le fil soixante fois par seconde.
  static const tick = Duration(milliseconds: 100);

  /// Ce que dure un son dont personne n'a mesuré la longueur. La doublure ne
  /// sait pas ouvrir un fichier : sans cette valeur, une pièce jointe sans
  /// durée annoncée se terminerait avant d'avoir commencé.
  static const unknownDuration = Duration(seconds: 3);

  InMemoryAudioPlayerService(this._store);

  @override
  Stream<AudioPlayback> get playback async* {
    yield _state;
    yield* _events.stream;
  }

  @override
  Future<void> play(String attachmentId) async {
    // Reprendre là où on s'était arrêté, mais seulement pour *cette* pièce
    // jointe : en changer remet à zéro, comme le ferait un nouveau lecteur.
    final resuming = _state.isFor(attachmentId);
    _publish(
      AudioPlayback(
        attachmentId: attachmentId,
        position: resuming ? _state.position : Duration.zero,
        duration: resuming && _state.duration > Duration.zero
            ? _state.duration
            : _durationOf(attachmentId),
        isPlaying: true,
      ),
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(tick, (_) => _advance());
  }

  @override
  Future<void> pause() async {
    if (!_state.isPlaying) return;
    _ticker?.cancel();
    _ticker = null;
    _publish(_state.copyWith(isPlaying: false));
  }

  @override
  Future<void> seek(String attachmentId, Duration position) async {
    final same = _state.isFor(attachmentId);
    // Viser un autre vocal arrête celui qui jouait, comme le ferait sa lecture.
    if (!same) {
      _ticker?.cancel();
      _ticker = null;
    }
    final duration = same && _state.duration > Duration.zero
        ? _state.duration
        : _durationOf(attachmentId);
    final bounded = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);
    _publish(
      AudioPlayback(
        attachmentId: attachmentId,
        position: bounded,
        duration: duration,
        isPlaying: same && _state.isPlaying,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _publish(AudioPlayback.idle);
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _events.close();
  }

  void _advance() {
    final position = _state.position + tick;
    if (position >= _state.duration) {
      // Un son qui va au bout ne laisse pas la bulle figée sur sa fin : elle
      // redevient prête à être rejouée.
      stop();
      return;
    }
    _publish(_state.copyWith(position: position));
  }

  void _publish(AudioPlayback state) {
    _state = state;
    if (!_events.isClosed) _events.add(state);
  }

  Duration _durationOf(String attachmentId) =>
      _store.attachmentById(attachmentId)?.duration ?? unknownDuration;
}
