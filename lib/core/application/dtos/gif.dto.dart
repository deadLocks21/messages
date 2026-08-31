import 'package:messages/core/domain/model/gif.dart';

/// Un GIF prêt pour la grille.
///
/// Ce que la vignette a besoin de savoir, et rien de plus : où chercher
/// l'aperçu, quelle place lui réserver, et comment l'annoncer. Les
/// déclinaisons joignables restent au domaine — la grille n'a pas à savoir
/// laquelle partira.
class GifDto {
  final String id;

  /// Ce que le catalogue dit du GIF. Sert de libellé d'accessibilité : une
  /// vignette animée sans texte ne s'annonce pas.
  final String description;

  /// L'adresse de l'aperçu. C'est la grille qui va la chercher, image par
  /// image, à mesure qu'elle défile.
  final String previewUrl;

  /// Le rapport largeur/hauteur de l'aperçu.
  ///
  /// Il est **connu avant le téléchargement**, et c'est ce qui permet à la
  /// grille en quinconce de réserver la bonne place tout de suite : sans lui,
  /// chaque GIF arrivé ferait sauter tous ceux d'en dessous.
  final double aspectRatio;

  const GifDto({
    required this.id,
    required this.description,
    required this.previewUrl,
    required this.aspectRatio,
  });

  factory GifDto.fromDomain(Gif gif) => GifDto(
    id: gif.id,
    description: gif.description,
    previewUrl: gif.preview.url,
    aspectRatio: gif.preview.aspectRatio,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GifDto && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Ce que la grille affiche, et si elle a encore de quoi défiler.
///
/// Les deux vont ensemble : sans [hasMore], la grille ne saurait pas s'il faut
/// demander la suite en arrivant en bas, ni si le témoin de chargement a
/// encore un sens. La position de reprise, elle, ne descend pas jusqu'ici —
/// c'est une affaire du catalogue.
class GifPageDto {
  final List<GifDto> gifs;
  final bool hasMore;

  /// Une page suivante est-elle en train d'arriver ?
  ///
  /// Distinct de [hasMore] : « il en reste » se sait tout le temps, « on est
  /// en train d'aller les chercher » ne dure qu'un instant. C'est le second
  /// qui allume le témoin en bas de la grille — l'allumer sur le premier le
  /// laisserait tourner en permanence, à annoncer une attente qui n'a pas
  /// commencé.
  final bool loadingMore;

  const GifPageDto({
    required this.gifs,
    required this.hasMore,
    this.loadingMore = false,
  });

  static const empty = GifPageDto(gifs: [], hasMore: false);

  GifPageDto loading(bool value) =>
      GifPageDto(gifs: gifs, hasMore: hasMore, loadingMore: value);
}

/// Une puce de recherche toute faite, sous le champ.
class GifCategoryDto {
  final String label;
  final String query;

  const GifCategoryDto({required this.label, required this.query});

  factory GifCategoryDto.fromDomain(GifCategory category) =>
      GifCategoryDto(label: category.label, query: category.query);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GifCategoryDto &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          query == other.query;

  @override
  int get hashCode => Object.hash(label, query);
}
