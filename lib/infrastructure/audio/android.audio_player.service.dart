import 'dart:async';

import 'package:flutter/services.dart';
import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/core/domain/services/audio_player.service.dart';

/// [AudioPlayerService] adossé au `MediaPlayer` d'Android.
///
/// Les octets ne traversent pas le canal, ici non plus : le natif ouvre
/// directement `content://mms/part/<id>`. Un vocal d'une minute serait, sinon,
/// recopié en mémoire Dart pour être aussitôt repassé au système.
///
/// Ce n'est donc pas Dart qui tient la position : c'est le lecteur du système
/// qui la publie, dix fois par seconde, sur `fr.dtfh.messages/audio_events`.
/// Une horloge côté Dart dériverait de la lecture réelle — d'un silence en
/// début de fichier, d'un décodage plus lent — et le curseur finirait par
/// mentir.
///
/// Contrat côté natif : voir `android/app/src/main/kotlin/.../AudioBridge.kt`.
class AndroidAudioPlayerService implements AudioPlayerService {
  static const _methods = MethodChannel('fr.dtfh.messages/audio');
  static const _events = EventChannel('fr.dtfh.messages/audio_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  /// Dernier état connu, ré-émis à toute nouvelle écoute.
  AudioPlayback _last = AudioPlayback.idle;

  AndroidAudioPlayerService({
    MethodChannel channel = _methods,
    EventChannel eventChannel = _events,
  }) : _channel = channel,
       _eventChannel = eventChannel;

  @override
  Stream<AudioPlayback> get playback async* {
    yield _last;
    await for (final event in _eventChannel.receiveBroadcastStream()) {
      _last = _playbackFrom(event);
      yield _last;
    }
  }

  @override
  Future<void> play(String attachmentId) =>
      _invoke('play', {'id': attachmentId});

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> seek(String attachmentId, Duration position) => _invoke('seek', {
    'id': attachmentId,
    'positionMs': position.inMilliseconds,
  });

  @override
  Future<void> stop() => _invoke('stop');

  /// Un vocal illisible — partie effacée, format que l'appareil ne décode pas —
  /// ne doit pas remonter en exception jusqu'au fil : le natif rend la main sur
  /// un état vide, et la bulle retrouve son bouton « lire ».
  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      _last = AudioPlayback.idle;
    } on MissingPluginException {
      _last = AudioPlayback.idle;
    }
  }

  AudioPlayback _playbackFrom(Object? event) {
    if (event is! Map) return AudioPlayback.idle;
    final data = event.map((key, value) => MapEntry(key.toString(), value));
    final id = data['attachmentId'] as String?;
    if (id == null) return AudioPlayback.idle;
    return AudioPlayback(
      attachmentId: id,
      position: Duration(milliseconds: (data['positionMs'] as int?) ?? 0),
      duration: Duration(milliseconds: (data['durationMs'] as int?) ?? 0),
      isPlaying: (data['isPlaying'] as bool?) ?? false,
    );
  }
}
