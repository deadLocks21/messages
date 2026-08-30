import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/waveform.dart';

/// Où en est l'enregistrement d'un vocal.
///
/// Trois états, et pas un de plus : c'est exactement ce que montre le panneau
/// de l'app d'origine — « appuyez pour enregistrer », l'enregistrement en
/// cours, puis la relecture avant de joindre.
enum VoiceRecordingPhase {
  /// Le micro est à l'arrêt : rien n'a encore été dit, ou ce qui l'avait été a
  /// été jeté.
  idle,

  recording,

  /// Enregistré, pas encore joint. C'est le seul moment où l'on peut se
  /// réécouter avant que le destinataire le fasse.
  recorded,
}

/// L'état d'un enregistrement en cours, tel que le panneau le peint.
///
/// Valeur immuable, republiée à chaque relevé de niveau — même contrat que
/// [AudioPlayback] pour la lecture : le panneau ne tient pas le micro, il
/// reconnaît l'état qu'on lui publie.
class VoiceRecording {
  final VoiceRecordingPhase phase;

  /// Ce qui a été enregistré jusqu'ici. C'est le compteur du panneau, et il ne
  /// vient pas d'une horloge Dart : le micro est la seule source qui sache
  /// combien de son a réellement été écrit.
  final Duration elapsed;

  /// Le relief de ce qui a été dit, un niveau par relevé, du plus ancien au
  /// plus récent. Vide au départ — un enregistrement qui n'a pas commencé n'a
  /// pas de silhouette.
  final Waveform waveform;

  /// L'appareil sait-il retirer le bruit de fond ? Le panneau l'annonce, comme
  /// l'app d'origine, et se tait quand l'appareil ne le propose pas : promettre
  /// une suppression du bruit inexistante ferait parler plus fort pour rien.
  final bool noiseSuppression;

  const VoiceRecording({
    this.phase = VoiceRecordingPhase.idle,
    this.elapsed = Duration.zero,
    this.waveform = Waveform.empty,
    this.noiseSuppression = false,
  });

  /// Rien en cours. C'est l'état d'ouverture du panneau, et celui où le ramène
  /// « Recommencer ».
  static const idle = VoiceRecording();

  bool get isRecording => phase == VoiceRecordingPhase.recording;

  /// Y a-t-il quelque chose à écouter, ou à joindre ?
  bool get isRecorded => phase == VoiceRecordingPhase.recorded;

  /// Débit du codec dans lequel part un vocal — AMR-NB à 12,2 kbit/s, en
  /// octets par seconde.
  ///
  /// Écrit ici parce que c'est **une règle de l'envoi**, pas un réglage
  /// d'encodeur : c'est ce débit qui dit combien de temps un vocal peut durer
  /// sans dépasser ce que l'opérateur accepte de porter. L'infrastructure qui
  /// enregistre doit tenir ce débit, faute de quoi la limite ci-dessous
  /// mentirait.
  static const bytesPerSecond = 1525;

  /// Le vocal le plus long qu'un MMS puisse porter chez cet opérateur.
  ///
  /// Comme pour une photo, la limite se pose **pendant** l'enregistrement et
  /// non à l'envoi : découvrir au retour du MMSC que le message est trop lourd
  /// laisserait perdre ce qui vient d'être dit, et c'est irrattrapable — une
  /// photo se reprend, une phrase se redit mal.
  ///
  /// [ceiling] borne le tout indépendamment de l'opérateur : un opérateur
  /// généreux autoriserait un vocal de dix minutes, que personne n'écoutera.
  static Duration maxDurationIn(MmsLimits limits) {
    final budget = Duration(seconds: limits.contentBytes ~/ bytesPerSecond);
    return budget < ceiling ? budget : ceiling;
  }

  /// Au-delà, ce n'est plus un message mais un enregistrement.
  static const ceiling = Duration(minutes: 5);

  /// En deçà, il n'y a rien à envoyer : un appui malheureux sur le micro puis
  /// sur « stop » ne doit pas produire une pièce jointe muette.
  static const minimum = Duration(milliseconds: 500);

  VoiceRecording copyWith({
    VoiceRecordingPhase? phase,
    Duration? elapsed,
    Waveform? waveform,
    bool? noiseSuppression,
  }) => VoiceRecording(
    phase: phase ?? this.phase,
    elapsed: elapsed ?? this.elapsed,
    waveform: waveform ?? this.waveform,
    noiseSuppression: noiseSuppression ?? this.noiseSuppression,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceRecording &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          elapsed == other.elapsed &&
          identical(waveform, other.waveform) &&
          noiseSuppression == other.noiseSuppression;

  @override
  int get hashCode => Object.hash(phase, elapsed, waveform, noiseSuppression);
}
