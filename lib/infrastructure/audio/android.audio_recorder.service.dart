import 'dart:async';

import 'package:flutter/services.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/core/domain/services/audio_recorder.service.dart';
import 'package:permission_handler/permission_handler.dart';

/// [AudioRecorderService] adossé au `MediaRecorder` d'Android.
///
/// Sur le **même canal** que la lecture (`fr.dtfh.messages/audio`) : micro et
/// haut-parleur vivent tous deux sur le fil principal, là où leurs rappels sont
/// livrés, et se disputent le même focus audio. Les séparer aurait obligé à
/// synchroniser deux ponts pour une règle qui tient en une phrase — on
/// n'enregistre pas pendant qu'on écoute.
///
/// Le niveau du micro est **relevé côté natif** dix fois par seconde, comme la
/// position de lecture : une amplitude ne se devine pas depuis Dart, et un
/// compteur Dart dériverait de ce qui a vraiment été écrit dans le fichier.
///
/// Contrat côté natif : voir `android/app/src/main/kotlin/.../AudioRecorder.kt`.
class AndroidAudioRecorderService implements AudioRecorderService {
  static const _methods = MethodChannel('fr.dtfh.messages/audio');
  static const _events = EventChannel('fr.dtfh.messages/recorder_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final LoggerApplicationService? _logger;

  /// Dernier état connu, ré-émis à toute nouvelle écoute — le panneau qui se
  /// reconstruit n'attend pas le relevé suivant pour savoir quoi peindre.
  VoiceRecording _last = VoiceRecording.idle;

  AndroidAudioRecorderService({
    MethodChannel channel = _methods,
    EventChannel eventChannel = _events,
    LoggerApplicationService? logger,
  }) : _channel = channel,
       _eventChannel = eventChannel,
       _logger = logger;

  @override
  Stream<VoiceRecording> get recording async* {
    yield _last;
    await for (final event in _eventChannel.receiveBroadcastStream()) {
      _last = _recordingFrom(event);
      yield _last;
    }
  }

  @override
  Future<void> start({required Duration maxDuration}) async {
    // La permission se demande **au moment du geste**, et pas à l'accueil avec
    // les SMS : un utilisateur qui n'envoie jamais de vocal n'a aucune raison
    // d'accorder son micro à une app de SMS. C'est aussi ce que fait l'app
    // d'origine.
    final status = await Permission.microphone.request();
    if (!status.isGranted) throw const MicrophoneDeniedException();

    try {
      await _channel.invokeMethod<void>('recordStart', {
        'maxDurationMs': maxDuration.inMilliseconds,
      });
    } on PlatformException catch (e, stack) {
      _last = VoiceRecording.idle;
      _logger?.warn(
        'voice.platform_error',
        attrs: {'audio.method': 'recordStart', 'audio.error_code': e.code},
        error: e,
        stack: stack,
      );
      throw const VoiceRecordingFailedException();
    } on MissingPluginException catch (e, stack) {
      _last = VoiceRecording.idle;
      _logger?.error(
        'audio.channel_missing',
        attrs: {'audio.method': 'recordStart'},
        error: e,
        stack: stack,
      );
      throw const VoiceRecordingFailedException();
    }
  }

  @override
  Future<AttachmentDraft?> stop() async {
    final Map<Object?, Object?>? raw;
    try {
      raw = await _channel.invokeMethod<Map<Object?, Object?>>('recordStop', {
        'minimumMs': VoiceRecording.minimum.inMilliseconds,
      });
    } on PlatformException catch (e, stack) {
      // Un enregistrement qui ne se referme pas ne laisse rien à joindre, mais
      // ne casse pas le fil : le panneau redevient vide.
      _last = VoiceRecording.idle;
      _logger?.warn(
        'voice.platform_error',
        attrs: {'audio.method': 'recordStop', 'audio.error_code': e.code},
        error: e,
        stack: stack,
      );
      return null;
    } on MissingPluginException {
      _last = VoiceRecording.idle;
      return null;
    }
    if (raw == null) return null;

    final data = raw.map((key, value) => MapEntry(key.toString(), value));
    final uri = data['uri'] as String?;
    if (uri == null) return null;

    return AttachmentDraft(
      id: data['id'] as String? ?? uri,
      uri: uri,
      mimeType: data['mimeType'] as String? ?? 'audio/amr',
      fileName: data['fileName'] as String? ?? 'Message vocal.amr',
      byteSize: (data['byteSize'] as int?) ?? 0,
      durationMs: data['durationMs'] as int?,
    );
  }

  @override
  Future<void> discard() async {
    try {
      await _channel.invokeMethod<void>('recordDiscard');
    } on PlatformException catch (e, stack) {
      _logger?.warn(
        'voice.platform_error',
        attrs: {'audio.method': 'recordDiscard', 'audio.error_code': e.code},
        error: e,
        stack: stack,
      );
    } on MissingPluginException {
      // Rien à jeter : il n'y a pas de natif pour l'avoir enregistré.
    }
    _last = VoiceRecording.idle;
  }

  VoiceRecording _recordingFrom(Object? event) {
    if (event is! Map) return VoiceRecording.idle;
    final data = event.map((key, value) => MapEntry(key.toString(), value));
    final phase = switch (data['phase'] as String?) {
      'recording' => VoiceRecordingPhase.recording,
      'recorded' => VoiceRecordingPhase.recorded,
      _ => VoiceRecordingPhase.idle,
    };
    final levels = (data['levels'] as List<Object?>?) ?? const [];
    return VoiceRecording(
      phase: phase,
      elapsed: Duration(milliseconds: (data['elapsedMs'] as int?) ?? 0),
      waveform: Waveform([
        for (final level in levels)
          ((level as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      ]),
      noiseSuppression: (data['noiseSuppression'] as bool?) ?? false,
    );
  }
}
