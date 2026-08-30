import 'package:messages/core/domain/model/audio_playback.dart';

/// Lecture des pièces jointes sonores — les vocaux, au premier chef.
///
/// **Un seul son à la fois.** Demander la lecture d'une pièce jointe arrête
/// celle qui jouait : deux vocaux superposés ne s'écoutent pas, et le lecteur
/// du système n'existe de toute façon qu'en un exemplaire. C'est donc une règle
/// du port, pas une précaution de l'appelant.
///
/// ## Ce que désigne `attachmentId`
///
/// Deux formes, et l'appelant n'a pas à les distinguer : l'identifiant d'une
/// **partie du stock** (`content://mms/part/<id>`), ou l'**URI d'un brouillon**
/// pas encore envoyé — le vocal qu'on vient d'enregistrer et qu'on veut
/// réécouter avant de le joindre. Un son est un son ; c'est l'implémentation
/// qui sait lequel des deux elle a sous la main.
abstract interface class AudioPlayerService {
  /// État de la lecture, republié à chaque avancée.
  ///
  /// Le flux **commence par l'état du moment** : une bulle qui arrive à l'écran
  /// pendant qu'un vocal joue sait immédiatement quoi peindre, sans attendre la
  /// prochaine émission.
  Stream<AudioPlayback> get playback;

  /// Lance [attachmentId] depuis le début, ou reprend là où une pause l'avait
  /// laissé.
  Future<void> play(String attachmentId);

  /// Suspend sans oublier la position. Sans effet si rien ne joue.
  Future<void> pause();

  /// Déplace la tête de lecture de [attachmentId] : qu'il joue, qu'il soit en
  /// pause ou qu'il n'ait jamais été lancé.
  ///
  /// D'où l'identifiant, là où « la lecture en cours » aurait suffi : viser un
  /// point d'un vocal, c'est aussi le choisir. Il devient alors la pièce jointe
  /// courante, à sa nouvelle position, mais **sans démarrer** — on décide où
  /// commencer, on décidera ensuite d'écouter.
  Future<void> seek(String attachmentId, Duration position);

  /// Arrête et oublie la position.
  Future<void> stop();
}
