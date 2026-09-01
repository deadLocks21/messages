// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reaction_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Le repli des réactions est-il actif ? Persisté derrière son port.
///
/// Le couper ne perd rien : les réactions redeviennent les messages qu'elles
/// n'ont jamais cessé d'être dans le stock — `Liked “Bonjour”`, en toutes
/// lettres. C'est exactement ce qu'il faut voir quand on cherche à comprendre
/// ce qu'un correspondant a réellement envoyé.

@ProviderFor(ReactionFoldingController)
final reactionFoldingControllerProvider = ReactionFoldingControllerProvider._();

/// Le repli des réactions est-il actif ? Persisté derrière son port.
///
/// Le couper ne perd rien : les réactions redeviennent les messages qu'elles
/// n'ont jamais cessé d'être dans le stock — `Liked “Bonjour”`, en toutes
/// lettres. C'est exactement ce qu'il faut voir quand on cherche à comprendre
/// ce qu'un correspondant a réellement envoyé.
final class ReactionFoldingControllerProvider
    extends $AsyncNotifierProvider<ReactionFoldingController, bool> {
  /// Le repli des réactions est-il actif ? Persisté derrière son port.
  ///
  /// Le couper ne perd rien : les réactions redeviennent les messages qu'elles
  /// n'ont jamais cessé d'être dans le stock — `Liked “Bonjour”`, en toutes
  /// lettres. C'est exactement ce qu'il faut voir quand on cherche à comprendre
  /// ce qu'un correspondant a réellement envoyé.
  ReactionFoldingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reactionFoldingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reactionFoldingControllerHash();

  @$internal
  @override
  ReactionFoldingController create() => ReactionFoldingController();
}

String _$reactionFoldingControllerHash() =>
    r'382559abc09d4cdbf75fc704eeb0d59a80180a13';

/// Le repli des réactions est-il actif ? Persisté derrière son port.
///
/// Le couper ne perd rien : les réactions redeviennent les messages qu'elles
/// n'ont jamais cessé d'être dans le stock — `Liked “Bonjour”`, en toutes
/// lettres. C'est exactement ce qu'il faut voir quand on cherche à comprendre
/// ce qu'un correspondant a réellement envoyé.

abstract class _$ReactionFoldingController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
