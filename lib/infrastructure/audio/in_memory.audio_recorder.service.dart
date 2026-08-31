import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/core/domain/services/audio_recorder.service.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';
import 'package:uuid/uuid.dart';

/// [AudioRecorderService] simulé : il n'écoute rien, il compte.
///
/// Ce qu'on vérifie d'un enregistrement n'a pas besoin d'un micro : que le
/// compteur avance, que la piste se remplisse, que « Recommencer » remette à
/// zéro, que le budget de l'opérateur arrête l'enregistrement tout seul, et
/// qu'au bout du geste il y ait un brouillon joignable. La doublure reproduit
/// exactement cela, et **dépose un vrai contenu** dans le stock simulé — sans
/// quoi la relecture avant envoi n'aurait rien à jouer.
///
/// Les niveaux ne sont pas tirés au hasard à chaque frame : ils sont semés sur
/// le rang du relevé, pour qu'un même enregistrement se redessine à
/// l'identique d'un rebuild à l'autre.
class InMemoryAudioRecorderService implements AudioRecorderService {
  final InMemorySmsStore _store;
  final Uuid _uuid = const Uuid();

  final StreamController<VoiceRecording> _events =
      StreamController<VoiceRecording>.broadcast();

  VoiceRecording _state = VoiceRecording.idle;
  Timer? _ticker;
  final List<double> _levels = [];

  /// Le vocal enregistré, tant qu'il n'a pas été relevé par [stop] ni jeté.
  AttachmentDraft? _finished;

  Duration _maxDuration = VoiceRecording.ceiling;

  /// Cadence des relevés de niveau, celle du natif.
  static const tick = Duration(milliseconds: 100);

  /// Quand vrai, la prochaine demande de micro est refusée — le cas que l'UI
  /// doit savoir dire.
  bool denyNext;

  InMemoryAudioRecorderService(this._store, {this.denyNext = false});

  @override
  Stream<VoiceRecording> get recording async* {
    yield _state;
    yield* _events.stream;
  }

  @override
  Future<void> start({required Duration maxDuration}) async {
    if (denyNext) {
      denyNext = false;
      throw const MicrophoneDeniedException();
    }
    _levels.clear();
    _finished = null;
    _maxDuration = maxDuration;
    _publish(
      const VoiceRecording(
        phase: VoiceRecordingPhase.recording,
        // La doublure annonce la suppression du bruit : c'est l'état nominal
        // d'un appareil récent, et c'est celui que le panneau doit savoir
        // peindre.
        noiseSuppression: true,
      ),
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(tick, (_) => _advance());
  }

  @override
  Future<AttachmentDraft?> stop() async {
    if (_state.isRecording) _finish();
    final draft = _finished;
    if (draft == null && !_state.isRecorded) _publish(VoiceRecording.idle);
    return draft;
  }

  @override
  Future<void> discard() async {
    _ticker?.cancel();
    _ticker = null;
    _levels.clear();
    final draft = _finished;
    if (draft != null) {
      _store.discardDraftSource(draft.uri);
      _store.discardDraft(draft.id);
    }
    _finished = null;
    _publish(VoiceRecording.idle);
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _events.close();
  }

  void _advance() {
    final elapsed = _state.elapsed + tick;
    _levels.add(_levelAt(_levels.length));
    _publish(
      _state.copyWith(elapsed: elapsed, waveform: Waveform(List.of(_levels))),
    );
    // Le budget de l'opérateur est atteint : le micro se referme de lui-même,
    // et ce qui a été dit reste joignable.
    if (elapsed >= _maxDuration) _finish();
  }

  /// Referme le micro et fabrique le brouillon, comme le fait le natif quand
  /// on appuie sur « stop » ou que la borne de durée est atteinte.
  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    final elapsed = _state.elapsed;
    if (elapsed < VoiceRecording.minimum) {
      _levels.clear();
      _publish(VoiceRecording.idle);
      return;
    }

    final draft = AttachmentDraft(
      id: _uuid.v4(),
      uri: 'memory://voice-${_uuid.v4()}.amr',
      mimeType: 'audio/amr',
      fileName: 'Message vocal.amr',
      // Le poids d'un AMR-NB est celui de sa durée : c'est un débit constant,
      // et c'est ce qui permet de borner un vocal au budget de l'opérateur.
      byteSize:
          (elapsed.inMilliseconds * VoiceRecording.bytesPerSecond) ~/ 1000,
      durationMs: elapsed.inMilliseconds,
    );
    // Un contenu, même fictif : sans lui, la relecture avant envoi n'aurait
    // rien à ouvrir et le plateau afficherait un vocal muet.
    _store.registerDraft(draft, Uint8List.fromList(List.filled(64, 0)));
    _finished = draft;

    _publish(
      _state.copyWith(
        phase: VoiceRecordingPhase.recorded,
        waveform: Waveform(List.of(_levels)),
      ),
    );
  }

  /// Une enveloppe de parole : des reprises de souffle, pas un plateau.
  double _levelAt(int index) {
    final phase = index / 12 * math.pi;
    final envelope = 0.35 + 0.65 * ((math.sin(phase) + 1) / 2);
    final grain = ((index * 2654435761) % 97) / 97;
    return ((0.2 + grain * 0.8) * envelope).clamp(0.0, 1.0);
  }

  void _publish(VoiceRecording state) {
    _state = state;
    if (!_events.isClosed) _events.add(state);
  }
}
