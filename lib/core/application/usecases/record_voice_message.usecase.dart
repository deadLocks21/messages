import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/core/domain/services/audio_recorder.service.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';

/// Enregistre un vocal et le rend prêt à poser sur le plateau.
///
/// Le pendant de [PickAttachmentsUseCase] pour le micro, et il en partage la
/// règle : **la taille se contrôle avant l'envoi, pas après**. La différence
/// est qu'un vocal ne s'allège pas — il n'y a rien à jeter dans une phrase.
/// La limite se pose donc en amont, sur la **durée** : le panneau sait combien
/// de temps il lui reste, et l'enregistrement s'arrête de lui-même plutôt que
/// de produire un fichier que le MMSC refusera.
///
/// C'est ce qui distingue un vocal d'une photo : une photo trop lourde se
/// reprend, une phrase se redit mal.
class RecordVoiceMessageUseCase {
  final AudioRecorderService _recorder;
  final MmsConfiguration _configuration;
  final LoggerApplicationService _logger;

  const RecordVoiceMessageUseCase({
    required AudioRecorderService recorder,
    required MmsConfiguration configuration,
    required LoggerApplicationService logger,
  }) : _recorder = recorder,
       _configuration = configuration,
       _logger = logger;

  Stream<VoiceRecording> get recording => _recorder.recording;

  /// Combien de temps un vocal peut durer chez cet opérateur.
  ///
  /// Lue et non devinée, comme le plafond des photos : c'est la même
  /// configuration opérateur, ramenée en secondes par le débit du codec.
  Future<Duration> maxDuration() async =>
      VoiceRecording.maxDurationIn(await _configuration.limits());

  /// Ouvre le micro.
  ///
  /// Propage [MicrophoneDeniedException] et [VoiceRecordingFailedException] :
  /// dans les deux cas l'utilisateur attend un enregistrement, et c'est la page
  /// qui sait le lui dire.
  Future<void> start() async {
    try {
      await _recorder.start(maxDuration: await maxDuration());
    } on SmsException catch (e) {
      // Un micro refusé n'est pas une panne de l'app, mais il rend la
      // fonctionnalité invisible : sans cette ligne, « le bouton ne fait rien »
      // reste inexplicable à distance.
      await _logger.warn(
        'voice.record_refused',
        attrs: {'voice.reason': e.runtimeType.toString()},
      );
      rethrow;
    }
    await _logger.info('voice.record_started');
  }

  /// Ferme le micro et rend le brouillon.
  ///
  /// Rend `null` quand il n'y a rien à joindre — trop court, ou fichier vide.
  /// Lève [AttachmentTooLargeException] si le vocal dépasse malgré tout le
  /// budget : la borne de durée est un garde-fou, pas une garantie, un encodeur
  /// pouvant produire un débit plus élevé qu'annoncé.
  Future<AttachmentDraft?> stop() async {
    final draft = await _recorder.stop();
    if (draft == null) {
      await _logger.info(
        'voice.record_discarded',
        attrs: {'voice.reason': 'too_short'},
      );
      return null;
    }

    final limits = await _configuration.limits();
    if (draft.byteSize > limits.contentBytes) {
      // Le fichier est déjà écrit : le jeter tout de suite évite de laisser
      // traîner dans le cache un vocal que personne ne pourra envoyer.
      await _recorder.discard();
      await _logger.warn(
        'attachment.rejected',
        attrs: {
          'attachment.reason': 'voice_too_long',
          'attachment.mime': draft.mimeType,
          'attachment.bytes': draft.byteSize,
          'attachment.budget_bytes': limits.contentBytes,
        },
      );
      throw AttachmentTooLargeException(limits);
    }

    await _logger.info(
      'voice.recorded',
      attrs: {
        'attachment.mime': draft.mimeType,
        'attachment.bytes': draft.byteSize,
        'voice.duration_ms': draft.durationMs ?? 0,
      },
    );
    return draft;
  }

  /// Jette ce qui est en cours — « Annuler » comme « Recommencer ».
  Future<void> discard() async {
    await _recorder.discard();
    await _logger.info(
      'voice.record_discarded',
      attrs: {'voice.reason': 'user'},
    );
  }
}
