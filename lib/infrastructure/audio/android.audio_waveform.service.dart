import 'package:flutter/services.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/core/domain/services/audio_waveform.service.dart';

/// [AudioWaveformService] adossé au décodeur d'Android.
///
/// La mesure ne se fait pas ici : décoder un vocal, c'est le passer entier dans
/// `MediaCodec`, et les octets n'ont aucune raison de traverser le canal pour
/// finir en quelques dizaines de nombres. Le natif décode, réduit, et ne rend
/// que la silhouette.
///
/// Contrat côté natif : voir `android/app/src/main/kotlin/.../AudioWaveform.kt`.
class AndroidAudioWaveformService implements AudioWaveformService {
  static const _methods = MethodChannel('fr.dtfh.messages/audio');

  final MethodChannel _channel;

  const AndroidAudioWaveformService({MethodChannel channel = _methods})
    : _channel = channel;

  @override
  Future<Waveform?> of(String attachmentId, {int buckets = 64}) async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('waveform', {
        'id': attachmentId,
        'buckets': buckets,
      });
      if (raw == null || raw.isEmpty) return null;
      return Waveform([
        for (final level in raw) ((level as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      ]);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
