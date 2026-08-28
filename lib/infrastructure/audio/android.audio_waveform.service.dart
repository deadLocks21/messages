import 'package:flutter/services.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
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
  final LoggerApplicationService _logger;

  const AndroidAudioWaveformService({
    required LoggerApplicationService logger,
    MethodChannel channel = _methods,
  }) : _channel = channel,
       _logger = logger;

  @override
  Future<Waveform?> of(String attachmentId, {int buckets = 64}) async {
    // Le coût est mesuré et publié : « ça met longtemps » ne se corrige pas au
    // jugé, et un décodeur logiciel sur un vieil appareil ne va pas à la même
    // vitesse que le nôtre.
    final elapsed = Stopwatch()..start();
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('waveform', {
        'id': attachmentId,
        'buckets': buckets,
      });
      elapsed.stop();
      if (raw == null || raw.isEmpty) {
        _logger.debug(
          'waveform.missing',
          attrs: {'attachment_id': attachmentId, 'ms': elapsed.elapsedMilliseconds},
        );
        return null;
      }
      _logger.debug(
        'waveform.measured',
        attrs: {
          'attachment_id': attachmentId,
          'ms': elapsed.elapsedMilliseconds,
          'buckets': raw.length,
        },
      );
      return Waveform([
        for (final level in raw) ((level as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      ]);
    } on PlatformException catch (error) {
      _logger.warn('waveform.failed', attrs: {'attachment_id': attachmentId}, error: error);
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
