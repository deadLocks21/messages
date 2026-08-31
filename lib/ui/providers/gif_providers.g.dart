// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gif_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Les puces de recherche toute faite, sous le champ.
///
/// `keepAlive` implicite par le cache de Riverpod le temps que le panneau est
/// ouvert : ce sont des mots, ils ne changent pas d'une frappe à l'autre.

@ProviderFor(gifCategories)
final gifCategoriesProvider = GifCategoriesProvider._();

/// Les puces de recherche toute faite, sous le champ.
///
/// `keepAlive` implicite par le cache de Riverpod le temps que le panneau est
/// ouvert : ce sont des mots, ils ne changent pas d'une frappe à l'autre.

final class GifCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GifCategoryDto>>,
          List<GifCategoryDto>,
          FutureOr<List<GifCategoryDto>>
        >
    with
        $FutureModifier<List<GifCategoryDto>>,
        $FutureProvider<List<GifCategoryDto>> {
  /// Les puces de recherche toute faite, sous le champ.
  ///
  /// `keepAlive` implicite par le cache de Riverpod le temps que le panneau est
  /// ouvert : ce sont des mots, ils ne changent pas d'une frappe à l'autre.
  GifCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gifCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gifCategoriesHash();

  @$internal
  @override
  $FutureProviderElement<List<GifCategoryDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GifCategoryDto>> create(Ref ref) {
    return gifCategories(ref);
  }
}

String _$gifCategoriesHash() => r'2b7e66071b782ac350d9a1ebb16d11af7e6d7480';

/// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
/// avant.
///
/// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
/// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
/// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
/// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
///
/// La grille est **sans fin** : chaque page apporte sa position de reprise, et
/// [loadMore] la suit. Une page sans position est la dernière.

@ProviderFor(GifFeed)
final gifFeedProvider = GifFeedFamily._();

/// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
/// avant.
///
/// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
/// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
/// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
/// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
///
/// La grille est **sans fin** : chaque page apporte sa position de reprise, et
/// [loadMore] la suit. Une page sans position est la dernière.
final class GifFeedProvider
    extends $AsyncNotifierProvider<GifFeed, GifPageDto> {
  /// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
  /// avant.
  ///
  /// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
  /// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
  /// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
  /// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
  ///
  /// La grille est **sans fin** : chaque page apporte sa position de reprise, et
  /// [loadMore] la suit. Une page sans position est la dernière.
  GifFeedProvider._({
    required GifFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'gifFeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gifFeedHash();

  @override
  String toString() {
    return r'gifFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GifFeed create() => GifFeed();

  @override
  bool operator ==(Object other) {
    return other is GifFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gifFeedHash() => r'be8d1a7f8e51557aa990cac537babeda8d2ce304';

/// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
/// avant.
///
/// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
/// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
/// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
/// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
///
/// La grille est **sans fin** : chaque page apporte sa position de reprise, et
/// [loadMore] la suit. Une page sans position est la dernière.

final class GifFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          GifFeed,
          AsyncValue<GifPageDto>,
          GifPageDto,
          FutureOr<GifPageDto>,
          String
        > {
  GifFeedFamily._()
    : super(
        retry: null,
        name: r'gifFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
  /// avant.
  ///
  /// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
  /// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
  /// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
  /// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
  ///
  /// La grille est **sans fin** : chaque page apporte sa position de reprise, et
  /// [loadMore] la suit. Une page sans position est la dernière.

  GifFeedProvider call(String query) =>
      GifFeedProvider._(argument: query, from: this);

  @override
  String toString() => r'gifFeedProvider';
}

/// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
/// avant.
///
/// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
/// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
/// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
/// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
///
/// La grille est **sans fin** : chaque page apporte sa position de reprise, et
/// [loadMore] la suit. Une page sans position est la dernière.

abstract class _$GifFeed extends $AsyncNotifier<GifPageDto> {
  late final _$args = ref.$arg as String;
  String get query => _$args;

  FutureOr<GifPageDto> build(String query);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<GifPageDto>, GifPageDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GifPageDto>, GifPageDto>,
              AsyncValue<GifPageDto>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
