import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/voice_recording.dart';

/// Enregistrement d'un vocal, du micro jusqu'au brouillon prêt à joindre.
///
/// Port jumeau d'[AudioPlayerService] : **un seul enregistrement à la fois**,
/// et il ne vit pas dans la bulle qui l'affiche mais dans le port. Deux micros
/// ouverts n'existent pas plus que deux lecteurs, et le panneau ne fait que
/// reconnaître l'état qu'on lui publie.
///
/// Les octets ne traversent pas le canal, ici non plus : ce que rend [stop]
/// est une URI que l'infrastructure sait relire, exactement comme ce que rend
/// le sélecteur de pièces jointes. Un vocal de trois minutes n'a aucune raison
/// d'être recopié en mémoire Dart pour être aussitôt repassé au système.
abstract interface class AudioRecorderService {
  /// État de l'enregistrement, republié à chaque relevé de niveau.
  ///
  /// Le flux **commence par l'état du moment**, comme celui du lecteur : un
  /// panneau qui se reconstruit pendant un enregistrement sait immédiatement
  /// quoi peindre.
  Stream<VoiceRecording> get recording;

  /// Ouvre le micro et commence à écrire.
  ///
  /// [maxDuration] est ce que l'opérateur accepte de porter, ramené en
  /// secondes (cf. [VoiceRecording.maxDurationIn]). L'enregistrement s'arrête
  /// **de lui-même** en l'atteignant, et passe en
  /// [VoiceRecordingPhase.recorded] : ce qui a été dit jusque-là reste
  /// joignable. Couper depuis l'appelant laisserait passer le trajet du
  /// message, et un fichier hors budget.
  ///
  /// Lève [MicrophoneDeniedException] si l'utilisateur refuse le micro, et
  /// [VoiceRecordingFailedException] si l'appareil ne le donne pas (micro déjà
  /// pris par un appel, encodeur indisponible). Les deux se disent à
  /// l'utilisateur : dans les deux cas, il attend un enregistrement qui ne
  /// viendra pas.
  Future<void> start({required Duration maxDuration});

  /// Ferme le micro et rend ce qui a été dit, prêt à joindre.
  ///
  /// Rend `null` quand il n'y a rien à envoyer — moins de
  /// [VoiceRecording.minimum], ou fichier vide. Ce n'est pas une erreur : c'est
  /// un appui malheureux, et l'état repasse simplement à
  /// [VoiceRecordingPhase.idle].
  Future<AttachmentDraft?> stop();

  /// Jette ce qui est en cours ou vient d'être enregistré, et efface le
  /// fichier. Sans effet quand il n'y a rien.
  ///
  /// C'est ce que font **« Annuler » et « Recommencer »** : le premier referme
  /// le panneau, le second le laisse ouvert, mais tous deux repartent de rien.
  Future<void> discard();
}
