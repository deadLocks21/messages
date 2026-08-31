// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(audioPlayback)
final audioPlaybackProvider = AudioPlaybackProvider._();

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

final class AudioPlaybackProvider
    extends
        $FunctionalProvider<
          AsyncValue<AudioPlayback>,
          AudioPlayback,
          Stream<AudioPlayback>
        >
    with $FutureModifier<AudioPlayback>, $StreamProvider<AudioPlayback> {
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
  AudioPlaybackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlaybackProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlaybackHash();

  @$internal
  @override
  $StreamProviderElement<AudioPlayback> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AudioPlayback> create(Ref ref) {
    return audioPlayback(ref);
  }
}

String _$audioPlaybackHash() => r'05cef5d194505dc1800d8ab9b1459c067c5700e9';
