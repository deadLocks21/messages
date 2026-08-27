import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [MmsConfiguration] lue dans la configuration opérateur d'Android, **une
/// fois**.
///
/// La valeur ne bouge pas de la vie d'un processus — il faudrait changer de
/// SIM — alors qu'elle est consultée à chaque pièce jointe ajoutée. C'est la
/// promesse qui est mémorisée, pour que plusieurs ajouts simultanés se
/// partagent une seule lecture.
///
/// Un échec n'est pas mis en cache : au démarrage, la configuration opérateur
/// peut n'être pas encore résolue (SIM en cours d'initialisation), et rester
/// bloqué sur le repli condamnerait toute la session à comprimer plus que
/// nécessaire.
class AndroidMmsConfiguration implements MmsConfiguration {
  final AndroidSmsChannel _channel;
  final LoggerApplicationService _logger;

  AndroidMmsConfiguration(
    this._channel, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  Future<MmsLimits>? _pending;

  @override
  Future<MmsLimits> limits() => _pending ??= _read();

  /// Oublie la limite en mémoire : la prochaine lecture repartira du système.
  void invalidate() => _pending = null;

  Future<MmsLimits> _read() async {
    try {
      final bytes = await _channel.mmsMaxMessageSize();
      final limits = MmsLimits.fromCarrier(bytes);
      // L'opérateur n'a rien publié d'exploitable : on garde le repli, mais on
      // retentera plus tard plutôt que de figer ce demi-échec.
      if (limits == MmsLimits.fallback) {
        _pending = null;
        // Ce repli décide de la qualité de toutes les photos envoyées : quand
        // une image part visiblement plus dégradée que nécessaire, c'est la
        // première ligne à regarder.
        await _logger.warn(
          'mms.limits_fallback',
          attrs: {
            'mms.carrier_bytes': bytes,
            'mms.limit_bytes': limits.contentBytes,
          },
        );
      } else {
        await _logger.info(
          'mms.limits_read',
          attrs: {'mms.limit_bytes': limits.contentBytes},
        );
      }
      return limits;
    } catch (e, stack) {
      _pending = null;
      await _logger.warn(
        'mms.limits_failed',
        attrs: {'mms.limit_bytes': MmsLimits.fallback.contentBytes},
        error: e,
        stack: stack,
      );
      return MmsLimits.fallback;
    }
  }
}
