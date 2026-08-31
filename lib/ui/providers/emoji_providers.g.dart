// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emoji_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Les sections de la grille : les récents, puis les familles.
///
/// Seuls les récents sont lus quelque part — le reste est une constante du
/// domaine. C'est pourquoi il n'y a qu'un `Future` ici, et qu'il ne porte que
/// sur la première section.

@ProviderFor(EmojiSections)
final emojiSectionsProvider = EmojiSectionsProvider._();

/// Les sections de la grille : les récents, puis les familles.
///
/// Seuls les récents sont lus quelque part — le reste est une constante du
/// domaine. C'est pourquoi il n'y a qu'un `Future` ici, et qu'il ne porte que
/// sur la première section.
final class EmojiSectionsProvider
    extends $AsyncNotifierProvider<EmojiSections, List<EmojiSectionDto>> {
  /// Les sections de la grille : les récents, puis les familles.
  ///
  /// Seuls les récents sont lus quelque part — le reste est une constante du
  /// domaine. C'est pourquoi il n'y a qu'un `Future` ici, et qu'il ne porte que
  /// sur la première section.
  EmojiSectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emojiSectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emojiSectionsHash();

  @$internal
  @override
  EmojiSections create() => EmojiSections();
}

String _$emojiSectionsHash() => r'f7d810bfc0460d72932f570ca3bb7fff192cbf06';

/// Les sections de la grille : les récents, puis les familles.
///
/// Seuls les récents sont lus quelque part — le reste est une constante du
/// domaine. C'est pourquoi il n'y a qu'un `Future` ici, et qu'il ne porte que
/// sur la première section.

abstract class _$EmojiSections extends $AsyncNotifier<List<EmojiSectionDto>> {
  FutureOr<List<EmojiSectionDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<EmojiSectionDto>>, List<EmojiSectionDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<EmojiSectionDto>>,
                List<EmojiSectionDto>
              >,
              AsyncValue<List<EmojiSectionDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Les emoji dont le nom contient [query]. Une recherche vide ne rend rien —
/// c'est l'appelant qui retombe alors sur les sections.

@ProviderFor(emojiSearch)
final emojiSearchProvider = EmojiSearchFamily._();

/// Les emoji dont le nom contient [query]. Une recherche vide ne rend rien —
/// c'est l'appelant qui retombe alors sur les sections.

final class EmojiSearchProvider
    extends $FunctionalProvider<List<EmojiDto>, List<EmojiDto>, List<EmojiDto>>
    with $Provider<List<EmojiDto>> {
  /// Les emoji dont le nom contient [query]. Une recherche vide ne rend rien —
  /// c'est l'appelant qui retombe alors sur les sections.
  EmojiSearchProvider._({
    required EmojiSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'emojiSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$emojiSearchHash();

  @override
  String toString() {
    return r'emojiSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<EmojiDto>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<EmojiDto> create(Ref ref) {
    final argument = this.argument as String;
    return emojiSearch(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<EmojiDto> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<EmojiDto>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EmojiSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$emojiSearchHash() => r'eb606ecc228f2e58168c10fa2af520c8bed64ae0';

/// Les emoji dont le nom contient [query]. Une recherche vide ne rend rien —
/// c'est l'appelant qui retombe alors sur les sections.

final class EmojiSearchFamily extends $Family
    with $FunctionalFamilyOverride<List<EmojiDto>, String> {
  EmojiSearchFamily._()
    : super(
        retry: null,
        name: r'emojiSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Les emoji dont le nom contient [query]. Une recherche vide ne rend rien —
  /// c'est l'appelant qui retombe alors sur les sections.

  EmojiSearchProvider call(String query) =>
      EmojiSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'emojiSearchProvider';
}
