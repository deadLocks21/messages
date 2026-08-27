import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_providers.g.dart';

/// Lecture sonore en cours, telle que les bulles la peignent.
///
/// Un seul flux pour tout le fil : c'est le lecteur lui-même qui n'existe qu'en
/// un exemplaire, et chaque bulle y reconnaît — ou non — sa propre pièce
/// jointe. Ouvrir une famille par pièce jointe multiplierait les abonnements
/// sans rien apprendre de plus.
///
/// Auto-disposé, contrairement au lecteur : quitter le fil coupe l'écoute, pas
/// le son. Y revenir retrouve l'état courant, que le port ré-émet à la
/// première écoute.
@riverpod
Stream<AudioPlayback> audioPlayback(Ref ref) =>
    ref.watch(audioPlayerServiceProvider).playback;

/// Silhouette d'un vocal, mesurée à l'affichage de sa bulle.
///
/// Une famille par pièce jointe, comme pour les octets d'une image : la mesure
/// se demande quand la bulle arrive à l'écran, une fois. Elle peut ne rien
/// rendre — format indécodable, partie effacée — et la piste reste alors
/// neutre plutôt que d'afficher un relief inventé.
@riverpod
Future<Waveform?> audioWaveform(Ref ref, String attachmentId) =>
    ref.watch(audioWaveformServiceProvider).of(attachmentId);
