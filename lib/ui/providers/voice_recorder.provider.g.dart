// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_recorder.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Enregistrement en cours, tel que le panneau le peint.
///
/// Un seul flux pour tout l'écran, comme pour la lecture : le micro n'existe
/// qu'en un exemplaire, et rien ne servirait d'ouvrir un abonnement par
/// panneau.

@ProviderFor(voiceRecording)
final voiceRecordingProvider = VoiceRecordingProvider._();

/// Enregistrement en cours, tel que le panneau le peint.
///
/// Un seul flux pour tout l'écran, comme pour la lecture : le micro n'existe
/// qu'en un exemplaire, et rien ne servirait d'ouvrir un abonnement par
/// panneau.

final class VoiceRecordingProvider
    extends
        $FunctionalProvider<
          AsyncValue<VoiceRecording>,
          VoiceRecording,
          Stream<VoiceRecording>
        >
    with $FutureModifier<VoiceRecording>, $StreamProvider<VoiceRecording> {
  /// Enregistrement en cours, tel que le panneau le peint.
  ///
  /// Un seul flux pour tout l'écran, comme pour la lecture : le micro n'existe
  /// qu'en un exemplaire, et rien ne servirait d'ouvrir un abonnement par
  /// panneau.
  VoiceRecordingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceRecordingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceRecordingHash();

  @$internal
  @override
  $StreamProviderElement<VoiceRecording> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<VoiceRecording> create(Ref ref) {
    return voiceRecording(ref);
  }
}

String _$voiceRecordingHash() => r'c2570f7ef0215a5bc132dbaaeb2445f518c564af';

/// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
/// détient entre l'arrêt et « Joindre ».
///
/// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
/// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
/// l'autre poserait son enregistrement chez le mauvais destinataire.
///
/// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
/// exactement comme le plateau.

@ProviderFor(VoiceRecorder)
final voiceRecorderProvider = VoiceRecorderFamily._();

/// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
/// détient entre l'arrêt et « Joindre ».
///
/// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
/// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
/// l'autre poserait son enregistrement chez le mauvais destinataire.
///
/// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
/// exactement comme le plateau.
final class VoiceRecorderProvider
    extends $NotifierProvider<VoiceRecorder, VoiceRecorderState> {
  /// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
  /// détient entre l'arrêt et « Joindre ».
  ///
  /// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
  /// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
  /// l'autre poserait son enregistrement chez le mauvais destinataire.
  ///
  /// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
  /// exactement comme le plateau.
  VoiceRecorderProvider._({
    required VoiceRecorderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'voiceRecorderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$voiceRecorderHash();

  @override
  String toString() {
    return r'voiceRecorderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  VoiceRecorder create() => VoiceRecorder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceRecorderState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceRecorderState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VoiceRecorderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$voiceRecorderHash() => r'b6fe0c51bd0ee14dc092aa27b1637a289cdbf64e';

/// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
/// détient entre l'arrêt et « Joindre ».
///
/// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
/// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
/// l'autre poserait son enregistrement chez le mauvais destinataire.
///
/// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
/// exactement comme le plateau.

final class VoiceRecorderFamily extends $Family
    with
        $ClassFamilyOverride<
          VoiceRecorder,
          VoiceRecorderState,
          VoiceRecorderState,
          VoiceRecorderState,
          String
        > {
  VoiceRecorderFamily._()
    : super(
        retry: null,
        name: r'voiceRecorderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
  /// détient entre l'arrêt et « Joindre ».
  ///
  /// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
  /// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
  /// l'autre poserait son enregistrement chez le mauvais destinataire.
  ///
  /// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
  /// exactement comme le plateau.

  VoiceRecorderProvider call(String threadId) =>
      VoiceRecorderProvider._(argument: threadId, from: this);

  @override
  String toString() => r'voiceRecorderProvider';
}

/// Le panneau d'enregistrement d'un fil : son ouverture, et le vocal qu'il
/// détient entre l'arrêt et « Joindre ».
///
/// Indexé par `threadId` comme le plateau : c'est vers *ce* plateau-là que
/// partira le vocal, et un panneau qui suivrait l'utilisateur d'un fil à
/// l'autre poserait son enregistrement chez le mauvais destinataire.
///
/// Le brouillon du **domaine** reste privé : le panneau n'en voit que le DTO,
/// exactement comme le plateau.

abstract class _$VoiceRecorder extends $Notifier<VoiceRecorderState> {
  late final _$args = ref.$arg as String;
  String get threadId => _$args;

  VoiceRecorderState build(String threadId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VoiceRecorderState, VoiceRecorderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VoiceRecorderState, VoiceRecorderState>,
              VoiceRecorderState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
