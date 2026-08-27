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

/// Silhouette d'un vocal, mesurée à l'affichage de sa bulle.
///
/// Une famille par pièce jointe, comme pour les octets d'une image : la mesure
/// se demande quand la bulle arrive à l'écran, une fois. Elle peut ne rien
/// rendre — format indécodable, partie effacée — et la piste reste alors
/// neutre plutôt que d'afficher un relief inventé.

@ProviderFor(audioWaveform)
final audioWaveformProvider = AudioWaveformFamily._();

/// Silhouette d'un vocal, mesurée à l'affichage de sa bulle.
///
/// Une famille par pièce jointe, comme pour les octets d'une image : la mesure
/// se demande quand la bulle arrive à l'écran, une fois. Elle peut ne rien
/// rendre — format indécodable, partie effacée — et la piste reste alors
/// neutre plutôt que d'afficher un relief inventé.

final class AudioWaveformProvider
    extends
        $FunctionalProvider<
          AsyncValue<Waveform?>,
          Waveform?,
          FutureOr<Waveform?>
        >
    with $FutureModifier<Waveform?>, $FutureProvider<Waveform?> {
  /// Silhouette d'un vocal, mesurée à l'affichage de sa bulle.
  ///
  /// Une famille par pièce jointe, comme pour les octets d'une image : la mesure
  /// se demande quand la bulle arrive à l'écran, une fois. Elle peut ne rien
  /// rendre — format indécodable, partie effacée — et la piste reste alors
  /// neutre plutôt que d'afficher un relief inventé.
  AudioWaveformProvider._({
    required AudioWaveformFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'audioWaveformProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioWaveformHash();

  @override
  String toString() {
    return r'audioWaveformProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Waveform?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Waveform?> create(Ref ref) {
    final argument = this.argument as String;
    return audioWaveform(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AudioWaveformProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioWaveformHash() => r'd27828f161481fc67af77ebb9ebe00fa981f055e';

/// Silhouette d'un vocal, mesurée à l'affichage de sa bulle.
///
/// Une famille par pièce jointe, comme pour les octets d'une image : la mesure
/// se demande quand la bulle arrive à l'écran, une fois. Elle peut ne rien
/// rendre — format indécodable, partie effacée — et la piste reste alors
/// neutre plutôt que d'afficher un relief inventé.

final class AudioWaveformFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Waveform?>, String> {
  AudioWaveformFamily._()
    : super(
        retry: null,
        name: r'audioWaveformProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Silhouette d'un vocal, mesurée à l'affichage de sa bulle.
  ///
  /// Une famille par pièce jointe, comme pour les octets d'une image : la mesure
  /// se demande quand la bulle arrive à l'écran, une fois. Elle peut ne rien
  /// rendre — format indécodable, partie effacée — et la piste reste alors
  /// neutre plutôt que d'afficher un relief inventé.

  AudioWaveformProvider call(String attachmentId) =>
      AudioWaveformProvider._(argument: attachmentId, from: this);

  @override
  String toString() => r'audioWaveformProvider';
}
