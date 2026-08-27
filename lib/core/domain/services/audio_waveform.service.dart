import 'package:messages/core/domain/model/waveform.dart';

/// Mesure de la silhouette d'une pièce jointe sonore.
///
/// Un port à part de `AudioPlayerService` : lire un son et le mesurer n'ont ni
/// le même coût, ni le même moment. La lecture est immédiate et suit un geste ;
/// la mesure demande de décoder tout le fichier, se fait **à l'affichage de la
/// bulle**, une fois, et se retient — c'est le même contrat qu'une vignette
/// d'image.
abstract interface class AudioWaveformService {
  /// Silhouette de [attachmentId] en [buckets] tranches.
  ///
  /// Rend `null` quand le son ne se décode pas — format inconnu, partie
  /// effacée du stock : la bulle garde alors une piste neutre plutôt que de
  /// dessiner un relief imaginaire.
  Future<Waveform?> of(String attachmentId, {int buckets});
}
