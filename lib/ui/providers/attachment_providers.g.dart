// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Plateau de pièces jointes d'un fil en cours de rédaction.
///
/// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
/// c'est lui qui fait la frontière, pour que ni la page ni le champ de
/// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
/// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
/// vide au même moment.
///
/// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
/// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.

@ProviderFor(AttachmentTray)
final attachmentTrayProvider = AttachmentTrayFamily._();

/// Plateau de pièces jointes d'un fil en cours de rédaction.
///
/// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
/// c'est lui qui fait la frontière, pour que ni la page ni le champ de
/// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
/// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
/// vide au même moment.
///
/// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
/// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.
final class AttachmentTrayProvider
    extends $NotifierProvider<AttachmentTray, List<AttachmentDraftDto>> {
  /// Plateau de pièces jointes d'un fil en cours de rédaction.
  ///
  /// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
  /// c'est lui qui fait la frontière, pour que ni la page ni le champ de
  /// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
  /// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
  /// vide au même moment.
  ///
  /// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
  /// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.
  AttachmentTrayProvider._({
    required AttachmentTrayFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'attachmentTrayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$attachmentTrayHash();

  @override
  String toString() {
    return r'attachmentTrayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AttachmentTray create() => AttachmentTray();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<AttachmentDraftDto> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<AttachmentDraftDto>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AttachmentTrayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$attachmentTrayHash() => r'9d5e53367e8a6b230a9f0631db93541ac7a4ff99';

/// Plateau de pièces jointes d'un fil en cours de rédaction.
///
/// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
/// c'est lui qui fait la frontière, pour que ni la page ni le champ de
/// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
/// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
/// vide au même moment.
///
/// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
/// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.

final class AttachmentTrayFamily extends $Family
    with
        $ClassFamilyOverride<
          AttachmentTray,
          List<AttachmentDraftDto>,
          List<AttachmentDraftDto>,
          List<AttachmentDraftDto>,
          String
        > {
  AttachmentTrayFamily._()
    : super(
        retry: null,
        name: r'attachmentTrayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Plateau de pièces jointes d'un fil en cours de rédaction.
  ///
  /// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
  /// c'est lui qui fait la frontière, pour que ni la page ni le champ de
  /// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
  /// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
  /// vide au même moment.
  ///
  /// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
  /// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.

  AttachmentTrayProvider call(String threadId) =>
      AttachmentTrayProvider._(argument: threadId, from: this);

  @override
  String toString() => r'attachmentTrayProvider';
}

/// Plateau de pièces jointes d'un fil en cours de rédaction.
///
/// Le contrôleur garde les brouillons du **domaine** et n'expose que des DTO :
/// c'est lui qui fait la frontière, pour que ni la page ni le champ de
/// rédaction n'aient à manipuler un `AttachmentDraft`. C'est aussi lui qui
/// envoie — le message et ses pièces jointes partent ensemble, et le plateau se
/// vide au même moment.
///
/// L'état est indexé par `threadId` : passer d'un fil à l'autre ne mélange pas
/// les plateaux, et revenir sur un fil retrouve ce qu'on y avait posé.

abstract class _$AttachmentTray extends $Notifier<List<AttachmentDraftDto>> {
  late final _$args = ref.$arg as String;
  String get threadId => _$args;

  List<AttachmentDraftDto> build(String threadId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<List<AttachmentDraftDto>, List<AttachmentDraftDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<AttachmentDraftDto>, List<AttachmentDraftDto>>,
              List<AttachmentDraftDto>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

/// Octets d'une pièce jointe **du stock**, pour sa vignette dans une bulle.
///
/// Une famille par identifiant de partie : Riverpod garde le résultat en cache
/// tant que la bulle est à l'écran, et le relit une seule fois même si le fil
/// se reconstruit.

@ProviderFor(attachmentBytes)
final attachmentBytesProvider = AttachmentBytesFamily._();

/// Octets d'une pièce jointe **du stock**, pour sa vignette dans une bulle.
///
/// Une famille par identifiant de partie : Riverpod garde le résultat en cache
/// tant que la bulle est à l'écran, et le relit une seule fois même si le fil
/// se reconstruit.

final class AttachmentBytesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// Octets d'une pièce jointe **du stock**, pour sa vignette dans une bulle.
  ///
  /// Une famille par identifiant de partie : Riverpod garde le résultat en cache
  /// tant que la bulle est à l'écran, et le relit une seule fois même si le fil
  /// se reconstruit.
  AttachmentBytesProvider._({
    required AttachmentBytesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'attachmentBytesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$attachmentBytesHash();

  @override
  String toString() {
    return r'attachmentBytesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return attachmentBytes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AttachmentBytesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$attachmentBytesHash() => r'3ac8a7a028e39c71395b1791e1fe9e765c3a6c35';

/// Octets d'une pièce jointe **du stock**, pour sa vignette dans une bulle.
///
/// Une famille par identifiant de partie : Riverpod garde le résultat en cache
/// tant que la bulle est à l'écran, et le relit une seule fois même si le fil
/// se reconstruit.

final class AttachmentBytesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, String> {
  AttachmentBytesFamily._()
    : super(
        retry: null,
        name: r'attachmentBytesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Octets d'une pièce jointe **du stock**, pour sa vignette dans une bulle.
  ///
  /// Une famille par identifiant de partie : Riverpod garde le résultat en cache
  /// tant que la bulle est à l'écran, et le relit une seule fois même si le fil
  /// se reconstruit.

  AttachmentBytesProvider call(String attachmentId) =>
      AttachmentBytesProvider._(argument: attachmentId, from: this);

  @override
  String toString() => r'attachmentBytesProvider';
}

/// Octets d'une pièce jointe **en cours de rédaction**, pour sa vignette dans
/// le plateau.

@ProviderFor(draftAttachmentBytes)
final draftAttachmentBytesProvider = DraftAttachmentBytesFamily._();

/// Octets d'une pièce jointe **en cours de rédaction**, pour sa vignette dans
/// le plateau.

final class DraftAttachmentBytesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// Octets d'une pièce jointe **en cours de rédaction**, pour sa vignette dans
  /// le plateau.
  DraftAttachmentBytesProvider._({
    required DraftAttachmentBytesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'draftAttachmentBytesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$draftAttachmentBytesHash();

  @override
  String toString() {
    return r'draftAttachmentBytesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return draftAttachmentBytes(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is DraftAttachmentBytesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$draftAttachmentBytesHash() =>
    r'3bebba21c814d64c5c2a78b6888a8a826227ffb2';

/// Octets d'une pièce jointe **en cours de rédaction**, pour sa vignette dans
/// le plateau.

final class DraftAttachmentBytesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, (String, String)> {
  DraftAttachmentBytesFamily._()
    : super(
        retry: null,
        name: r'draftAttachmentBytesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Octets d'une pièce jointe **en cours de rédaction**, pour sa vignette dans
  /// le plateau.

  DraftAttachmentBytesProvider call(String threadId, String draftId) =>
      DraftAttachmentBytesProvider._(argument: (threadId, draftId), from: this);

  @override
  String toString() => r'draftAttachmentBytesProvider';
}
