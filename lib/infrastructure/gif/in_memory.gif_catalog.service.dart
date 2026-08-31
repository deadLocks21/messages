import 'package:messages/core/domain/model/gif.dart';
import 'package:messages/core/domain/services/gif_catalog.service.dart';

/// Catalogue simulé : ni réseau, ni clé d'API.
///
/// Il ne montre aucun GIF — il n'en a pas — mais il en a **la forme** : des
/// rapports d'aspect variés pour que la grille en quinconce se dessine
/// vraiment, des poids de déclinaisons plausibles pour que le choix de taille
/// se joue pour de bon, une pagination qui s'arrête. C'est exactement ce que
/// fait `InMemoryAudioWaveformService` avec la silhouette d'un son : rien
/// d'inventé qui se ferait passer pour vrai, mais tout ce qu'il faut pour que
/// l'écran au-dessus soit développable et testable.
///
/// Les adresses portent le schéma `demo:` : la grille sait qu'il n'y a rien à
/// télécharger et peint une pastille à la place.
class InMemoryGifCatalog implements GifCatalog {
  /// Termes cherchés, dans l'ordre — ce que vérifient les tests d'UI.
  final List<String> searched = [];

  /// Quand vrai, toute lecture rend une page vide : le catalogue muet que
  /// l'écran doit savoir annoncer (hors ligne, quota épuisé).
  bool empty;

  InMemoryGifCatalog({this.empty = false});

  static const _pageSize = 20;

  /// Deux pages, pas plus : de quoi éprouver le défilement sans fin et sa fin.
  static const _totalPages = 2;

  static const _labels = [
    'Chat surpris',
    'Pouce levé',
    'Applaudissements',
    'Danse de la joie',
    'Yeux au ciel',
    'Câlin',
    'Fou rire',
    'Au revoir',
    'Bravo',
    'Facepalm',
  ];

  /// Les rapports d'aspect que sert un vrai catalogue : du panoramique au
  /// portrait, en passant par le carré. C'est ce qui met la grille en
  /// quinconce à l'épreuve — deux colonnes de hauteurs égales ne prouveraient
  /// rien.
  static const _shapes = [
    (498, 280),
    (498, 498),
    (498, 372),
    (360, 498),
    (498, 224),
    (440, 440),
  ];

  @override
  Future<GifPage> featured({String? cursor}) async => _page('démo', cursor);

  @override
  Future<GifPage> search(String query, {String? cursor}) async {
    searched.add(query);
    if (query.trim().isEmpty) return GifPage.empty;
    return _page(query.trim(), cursor);
  }

  GifPage _page(String seed, String? cursor) {
    if (empty) return GifPage.empty;
    final page = int.tryParse(cursor ?? '0') ?? 0;
    if (page >= _totalPages) return GifPage.empty;

    return GifPage(
      gifs: List.generate(
        _pageSize,
        (index) => _gif(seed, page * _pageSize + index),
      ),
      cursor: page + 1 < _totalPages ? '${page + 1}' : null,
    );
  }

  Gif _gif(String seed, int index) {
    final (width, height) = _shapes[index % _shapes.length];
    final label = _labels[index % _labels.length];
    final id = 'demo-${seed.hashCode.toUnsigned(16)}-$index';

    // Les poids suivent la surface, comme ceux d'un vrai GIF, et s'échelonnent
    // **autour** du budget d'un MMS : c'est ce qui fait que la démonstration
    // choisit vraiment une déclinaison au lieu de prendre la première.
    // [dixiemesParPixel] est le poids d'un pixel en dixièmes d'octet — une
    // image animée en pèse plusieurs, une vignette bien moins.
    GifRendition rendition(int percent, int dixiemesParPixel) {
      final w = width * percent ~/ 100;
      final h = height * percent ~/ 100;
      return GifRendition(
        url: 'demo://gif/$id/$percent',
        width: w,
        height: h,
        byteSize: w * h * dixiemesParPixel ~/ 10,
      );
    }

    return Gif(
      id: id,
      description: '$label GIF',
      preview: rendition(44, 8),
      renditions: [
        rendition(100, 30), // ≈ 400 ko : au-dessus du budget par défaut
        rendition(70, 17), // ≈ 110 ko : ce qui partira le plus souvent
        rendition(44, 8), // ≈ 21 ko : pour un opérateur avare
      ],
    );
  }
}
