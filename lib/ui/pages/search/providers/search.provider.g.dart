// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Résultats de recherche pour une requête. Auto-dispose : chaque frappe crée
/// une nouvelle instance, les précédentes n'ont pas à survivre.

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// Résultats de recherche pour une requête. Auto-dispose : chaque frappe crée
/// une nouvelle instance, les précédentes n'ont pas à survivre.

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchResultsDto>,
          SearchResultsDto,
          FutureOr<SearchResultsDto>
        >
    with $FutureModifier<SearchResultsDto>, $FutureProvider<SearchResultsDto> {
  /// Résultats de recherche pour une requête. Auto-dispose : chaque frappe crée
  /// une nouvelle instance, les précédentes n'ont pas à survivre.
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SearchResultsDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchResultsDto> create(Ref ref) {
    final argument = this.argument as String;
    return searchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'06e887a8211229ec6e3f774969ea01e1324d045f';

/// Résultats de recherche pour une requête. Auto-dispose : chaque frappe crée
/// une nouvelle instance, les précédentes n'ont pas à survivre.

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SearchResultsDto>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Résultats de recherche pour une requête. Auto-dispose : chaque frappe crée
  /// une nouvelle instance, les précédentes n'ont pas à survivre.

  SearchResultsProvider call(String query) =>
      SearchResultsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchResultsProvider';
}

/// Résultats dans un seul fil. Auto-dispose pour la même raison.

@ProviderFor(threadSearchResults)
final threadSearchResultsProvider = ThreadSearchResultsFamily._();

/// Résultats dans un seul fil. Auto-dispose pour la même raison.

final class ThreadSearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MessageHitDto>>,
          List<MessageHitDto>,
          FutureOr<List<MessageHitDto>>
        >
    with
        $FutureModifier<List<MessageHitDto>>,
        $FutureProvider<List<MessageHitDto>> {
  /// Résultats dans un seul fil. Auto-dispose pour la même raison.
  ThreadSearchResultsProvider._({
    required ThreadSearchResultsFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'threadSearchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$threadSearchResultsHash();

  @override
  String toString() {
    return r'threadSearchResultsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<MessageHitDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MessageHitDto>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return threadSearchResults(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ThreadSearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$threadSearchResultsHash() =>
    r'c62801f1b87e23884ff9c23d237fe94f6e9cd551';

/// Résultats dans un seul fil. Auto-dispose pour la même raison.

final class ThreadSearchResultsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MessageHitDto>>,
          (String, String)
        > {
  ThreadSearchResultsFamily._()
    : super(
        retry: null,
        name: r'threadSearchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Résultats dans un seul fil. Auto-dispose pour la même raison.

  ThreadSearchResultsProvider call(String threadId, String query) =>
      ThreadSearchResultsProvider._(argument: (threadId, query), from: this);

  @override
  String toString() => r'threadSearchResultsProvider';
}
