import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/gif.dart';
import 'package:messages/core/domain/services/gif_catalog.service.dart';

/// [GifCatalog] adossé à **Klipy**.
///
/// Écrit à la main sur `package:http`, comme l'expédition des logs : l'API est
/// trois requêtes GET et un objet JSON, là où un SDK ajouterait une dépendance
/// pour la même chose.
///
/// - **La clé n'est pas dans le dépôt.** Elle arrive par `--dart-define`, à
///   l'image de `SIGNOZ_INGEST_URL` ; sans elle, l'app monte
///   `InMemoryGifCatalog` et le panneau reste utilisable en démonstration.
/// - **La clé est dans le chemin**, pas dans un en-tête : c'est ainsi que
///   Klipy la veut (`/api/v1/<clé>/gifs/...`). Elle ne doit donc jamais partir
///   dans un log — d'où les journaux qui ne nomment que le point d'appel.
/// - Klipy pagine **par numéro de page** (`page`, `has_next`) là où d'autres
///   catalogues rendent une position opaque. `GifPage.cursor` porte donc le
///   numéro de la page suivante : le domaine n'a pas à savoir ce qu'il y a
///   dedans, c'est bien pour cela qu'il ne le lit jamais.
class KlipyGifCatalog implements GifCatalog {
  final http.Client _client;
  final String _apiKey;

  /// La langue dans laquelle les puces sont libellées (« mdr », « désolé »
  /// plutôt que « lol », « sorry ») et les résultats classés.
  final String _locale;
  final LoggerApplicationService _logger;

  KlipyGifCatalog({
    required http.Client client,
    required String apiKey,
    required LoggerApplicationService logger,
    String locale = 'fr_FR',
  }) : _client = client,
       _apiKey = apiKey,
       _locale = locale,
       _logger = logger;

  static const _host = 'api.klipy.com';

  /// Les quatre tailles de Klipy, de la plus lourde à la plus légère. Ce sont
  /// elles qui deviennent les déclinaisons joignables, en `gif`.
  static const _tiers = ['hd', 'md', 'sm', 'xs'];

  /// La taille servie à la grille, et son format.
  ///
  /// `sm` parce que c'est la seule qui soit à la fois lisible (192 px de large
  /// au relevé, pour une cellule de 193 dp) et raisonnable ; `hd` pèse dix
  /// fois plus pour la même chose. **En WebP** parce que le même dessin y
  /// tient en trois fois moins d'octets qu'en GIF (153 ko contre 448 à la
  /// médiane) et que Flutter l'anime aussi bien — et parce que rien ne part
  /// de l'aperçu : ce qui s'envoie sort des déclinaisons.
  static const _previewTier = 'sm';
  static const _previewFormat = 'webp';

  /// Ce qu'une page rapporte. Une grille à deux colonnes en montre huit à
  /// l'écran : vingt donnent de quoi défiler sans attendre, sans télécharger
  /// pour rien ce qui ne sera jamais vu.
  static const _pageSize = 20;

  @override
  Future<GifPage> featured({String? cursor}) => _page('trending', {}, cursor);

  @override
  Future<GifPage> search(String query, {String? cursor}) {
    // Une recherche vide n'est pas une recherche : c'est à l'appelant de
    // retomber sur `featured`, et Klipy refuserait la requête de toute façon.
    if (query.trim().isEmpty) return Future.value(GifPage.empty);
    return _page('search', {'q': query.trim()}, cursor);
  }

  @override
  Future<List<GifCategory>> categories() async {
    final body = await _get('categories', const {});
    final categories = _data(body)?['categories'];
    if (categories is! List) return const [];

    return categories
        .whereType<Map<String, Object?>>()
        .map(_category)
        .nonNulls
        .toList(growable: false);
  }

  Future<GifPage> _page(
    String endpoint,
    Map<String, String> query,
    String? cursor,
  ) async {
    final page = int.tryParse(cursor ?? '1') ?? 1;
    final body = await _get(endpoint, {
      ...query,
      'page': '$page',
      'per_page': '$_pageSize',
    });

    final data = _data(body);
    final results = data?['data'];
    if (results is! List) return GifPage.empty;

    return GifPage(
      gifs: results
          .whereType<Map<String, Object?>>()
          .map(_gif)
          .nonNulls
          .toList(growable: false),
      cursor: data!['has_next'] == true ? '${page + 1}' : null,
    );
  }

  /// L'enveloppe de Klipy : `{"result": true, "data": {…}}`. Un `result` faux
  /// est un refus applicatif, distinct d'un code HTTP.
  Map<String, Object?>? _data(Map<String, Object?>? body) {
    if (body == null || body['result'] != true) return null;
    final data = body['data'];
    return data is Map<String, Object?> ? data : null;
  }

  Future<Map<String, Object?>?> _get(
    String endpoint,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(_host, '/api/v1/$_apiKey/gifs/$endpoint', {
      ...query,
      'locale': _locale,
    });

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e, stack) {
      // Le catalogue est au bout du réseau : hors ligne, il n'y a pas de GIF,
      // et ce n'est pas une panne de l'app.
      await _logger.warn(
        'gif.request_failed',
        // Le point d'appel, et rien d'autre : l'URL porte la clé d'API, et le
        // terme cherché n'a pas à sortir de l'appareil.
        attrs: {'gif.endpoint': endpoint},
        error: e,
        stack: stack,
      );
      return null;
    }

    if (response.statusCode != 200) {
      await _logger.warn(
        'gif.request_rejected',
        attrs: {
          'gif.endpoint': endpoint,
          'http.status_code': response.statusCode,
        },
      );
      return null;
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (e, stack) {
      await _logger.warn(
        'gif.decode_failed',
        attrs: {'gif.endpoint': endpoint},
        error: e,
        stack: stack,
      );
      return null;
    }
  }

  /// Un résultat de Klipy, ou `null` s'il ne porte aucune déclinaison
  /// exploitable — un résultat sans GIF n'est pas une erreur, c'est un
  /// résultat de moins.
  Gif? _gif(Map<String, Object?> data) {
    // L'identifiant arrive en nombre, pas en chaîne.
    final id = data['id'];
    if (id == null || '$id'.isEmpty) return null;

    final file = data['file'];
    if (file is! Map) return null;

    final renditions = <GifRendition>[];
    for (final tier in _tiers) {
      final rendition = _rendition(file[tier], 'gif');
      if (rendition != null) renditions.add(rendition);
    }
    if (renditions.isEmpty) return null;

    // L'aperçu retombe sur la plus légère des déclinaisons quand Klipy ne sert
    // pas la taille voulue : mieux vaut une vignette lourde qu'une case vide.
    final preview =
        _rendition(file[_previewTier], _previewFormat) ?? renditions.last;

    final title = data['title'];
    return Gif(
      id: '$id',
      description: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'GIF',
      preview: preview,
      renditions: renditions,
      blurPreview: data['blur_preview'] is String
          ? data['blur_preview'] as String
          : null,
    );
  }

  GifRendition? _rendition(Object? tier, String format) {
    if (tier is! Map) return null;
    final data = tier[format];
    if (data is! Map) return null;

    final url = data['url'];
    final width = _int(data['width']);
    final height = _int(data['height']);
    if (url is! String || url.isEmpty) return null;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }

    return GifRendition(
      url: url,
      width: width,
      height: height,
      // Une déclinaison sans poids annoncé est traitée comme infiniment
      // lourde : `bestWithin` l'écartera plutôt que de la croire minuscule et
      // de faire refuser le MMS.
      byteSize: _int(data['size']) ?? _unknownSize,
    );
  }

  /// Ce qu'on prête à une déclinaison dont Klipy tait le poids : assez pour
  /// qu'aucun budget d'opérateur ne l'accepte.
  static const _unknownSize = 1 << 30;

  GifCategory? _category(Map<String, Object?> data) {
    final query = data['query'] ?? data['category'];
    if (query is! String || query.trim().isEmpty) return null;
    final label = data['category'];
    return GifCategory(
      // Klipy libelle ses catégories sans dièse ; la puce le porte, comme dans
      // l'app d'origine.
      label: '#${(label is String && label.trim().isNotEmpty ? label : query).trim()}',
      query: query.trim(),
    );
  }

  static int? _int(Object? value) => switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };
}
