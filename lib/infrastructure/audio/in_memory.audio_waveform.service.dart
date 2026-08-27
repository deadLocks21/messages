import 'dart:math' as math;

import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/core/domain/services/audio_waveform.service.dart';

/// [AudioWaveformService] simulé : il ne décode rien, il dessine.
///
/// La doublure n'a pas de son à mesurer — le stock en mémoire ne porte que des
/// octets fictifs. Elle fabrique donc une silhouette **stable** à partir de
/// l'identifiant : deux vocaux différents ne se ressemblent pas, et le même
/// vocal se redessine à l'identique d'un rebuild à l'autre. Une forme d'onde
/// qui frémirait à chaque frame trahirait tout de suite la doublure.
class InMemoryAudioWaveformService implements AudioWaveformService {
  const InMemoryAudioWaveformService();

  @override
  Future<Waveform?> of(String attachmentId, {int buckets = 64}) async {
    // Générateur congruentiel semé par l'identifiant : reproductible, et sans
    // dépendre de `Random` dont l'implémentation n'est pas garantie stable.
    var seed = attachmentId.hashCode.abs() % 2147483647;
    double next() {
      seed = (seed * 1103515245 + 12345) % 2147483647;
      return seed / 2147483647;
    }

    return Waveform(
      List.generate(buckets, (index) {
        // Une enveloppe de parole : des reprises de souffle, pas un plateau.
        final phase = index / buckets * math.pi * 3;
        final envelope = 0.35 + 0.65 * ((math.sin(phase) + 1) / 2);
        return ((0.15 + next() * 0.85) * envelope).clamp(0.0, 1.0);
      }),
    );
  }
}
