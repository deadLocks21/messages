import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/gif.dart';
import 'package:messages/core/domain/services/gif_catalog.service.dart';

/// [GifCatalog] adossé à **Tenor** — le catalogue de l'app d'origine.
///
/// Écrit à la main sur `package:http`, comme l'expédition des logs : l'API est
/// trois requêtes GET et un objet JSON, là où un SDK ajouterait une dépendance
/// pour la même chose.
///
/// - **La clé n'est pas dans le dépôt.** Elle arrive par `--dart-define`, à
///   l'image de `SIGNOZ_INGEST_URL` ; sans elle, l'app monte
///   `InMemoryGifCatalog` et le panneau reste utilisable en démonstration.
/// - **`media_filter` n'est pas une optimisation** : sans lui, Tenor renvoie
///   les quatorze déclinaisons de chaque résultat (MP4, WebM, aperçus fixes),
///   soit un JSON plusieurs fois plus gros pour des adresses qu'on n'ouvrira
///   jamais. On demande les quatre GIF animés, et c'est tout.
/// - **`contentfilter: high`** parce qu'un client SMS n'est pas un endroit où
///   l'on choisit de voir ce genre de choses par surprise. C'est le filtre le
///   plus strict de Tenor.
class TenorGifCatalog implements GifCatalog {
  final http.Client _client;
  final String _apiKey;

  /// Identifie l'app auprès de Tenor pour que les recherches et les partages
  /// se comptent ensemble, plutôt qu'anonymement pour chaque appareil.
  final String _clientKey;

  /// La langue dans laquelle les puces sont libellées (`#paresseux` plutôt que
  /// `#lazy`) et les résultats classés.
  final String _locale;
  final LoggerApplicationService _logger;

  TenorGifCatalog({
    required http.Client client,
    required String apiKey,
    required LoggerApplicationService logger,
    String clientKey = 'fr.dtfh.messages',
    String locale = 'fr_FR',
  }) : _client = client,
       _apiKey = apiKey,
       _clientKey = clientKey,
       _locale = locale,
       _logger = logger;

  static const _host = 'tenor.googleapis.com';

  /// Les déclinaisons demandées, de la plus lourde à la plus légère.
  ///
  /// `tinygif` sert d'aperçu (220 px de large au plus, ce qu'une grille en
  /// quinconce peut faire défiler par dizaines) et les quatre servent d'envoi
  /// — c'est parmi elles que [Gif.bestWithin] choisira.
  static const _formats = ['gif', 'mediumgif', 'tinygif', 'nanogif'];

  /// Ce qu'une page rapporte. Une grille à deux colonnes en montre huit à
  /// l'écran : vingt donnent de quoi défiler sans attendre, sans télécharger
  /// pour rien ce qui ne sera jamais vu.
  static const _pageSize = 20;

  @override
  Future<GifPage> featured({String? cursor}) =>
      _page('/v2/featured', {}, cursor);

  @override
  Future<GifPage> search(String query, {String? cursor}) {
    // Une recherche vide n'est pas une recherche : c'est à l'appelant de
    // retomber sur `featured`, et Tenor refuserait la requête de toute façon.
    if (query.trim().isEmpty) return Future.value(GifPage.empty);
    return _page('/v2/search', {'q': query.trim()}, cursor);
  }

  @override
  Future<List<GifCategory>> categories() async {
    final body = await _get('/v2/categories', {'type': 'trending'});
    if (body == null) return const [];

    final tags = body['tags'];
    if (tags is! List) return const [];

    return tags
        .whereType<Map<String, Object?>>()
        .map(_category)
        .nonNulls
        .toList(growable: false);
  }

  Future<GifPage> _page(
    String path,
    Map<String, String> query,
    String? cursor,
  ) async {
    final body = await _get(path, {
      ...query,
      'limit': '$_pageSize',
      'media_filter': _formats.join(','),
      if (cursor != null && cursor.isNotEmpty) 'pos': cursor,
    });
    if (body == null) return GifPage.empty;

    final results = body['results'];
    if (results is! List) return GifPage.empty;

    return GifPage(
      gifs: results
          .whereType<Map<String, Object?>>()
          .map(_gif)
          .nonNulls
          .toList(growable: false),
      cursor: body['next'] as String?,
    );
  }

  Future<Map<String, Object?>?> _get(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(_host, path, {
      ...query,
      'key': _apiKey,
      'client_key': _clientKey,
      'locale': _locale,
      'contentfilter': 'high',
    });

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e, stack) {
      // Le catalogue est au bout du réseau : hors ligne, il n'y a pas de GIF,
      // et ce n'est pas une panne de l'app.
      await _logger.warn(
        'gif.request_failed',
        // Ni la clé ni le terme cherché : `path` dit ce qu'on demandait, et
        // c'est tout ce qu'un tableau de bord a besoin de savoir.
        attrs: {'gif.path': path},
        error: e,
        stack: stack,
      );
      return null;
    }

    if (response.statusCode != 200) {
      await _logger.warn(
        'gif.request_rejected',
        attrs: {'gif.path': path, 'http.status_code': response.statusCode},
      );
      return null;
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (e, stack) {
      await _logger.warn(
        'gif.decode_failed',
        attrs: {'gif.path': path},
        error: e,
        stack: stack,
      );
      return null;
    }
  }

  /// Un résultat de Tenor, ou `null` s'il ne porte aucune déclinaison
  /// exploitable — un résultat sans GIF n'est pas une erreur, c'est un
  /// résultat de moins.
  Gif? _gif(Map<String, Object?> data) {
    final id = data['id'];
    if (id is! String || id.isEmpty) return null;

    final formats = data['media_formats'];
    if (formats is! Map) return null;

    final renditions = <String, GifRendition>{};
    for (final name in _formats) {
      final rendition = _rendition(formats[name]);
      if (rendition != null) renditions[name] = rendition;
    }
    if (renditions.isEmpty) return null;

    // L'aperçu est la plus légère qu'on ait demandée, et pas forcément
    // `tinygif` : Tenor ne sert pas toujours les quatre.
    final preview = renditions['tinygif'] ?? renditions.values.last;

    return Gif(
      id: id,
      description: (data['content_description'] as String?)?.trim().isNotEmpty
              == true
          ? data['content_description'] as String
          : 'GIF',
      preview: preview,
      renditions: renditions.values.toList(growable: false),
    );
  }

  GifRendition? _rendition(Object? data) {
    if (data is! Map) return null;
    final url = data['url'];
    final dims = data['dims'];
    if (url is! String || url.isEmpty) return null;
    if (dims is! List || dims.length < 2) return null;

    final width = _int(dims[0]);
    final height = _int(dims[1]);
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

  /// Ce qu'on prête à une déclinaison dont Tenor tait le poids : assez pour
  /// qu'aucun budget d'opérateur ne l'accepte.
  static const _unknownSize = 1 << 30;

  GifCategory? _category(Map<String, Object?> data) {
    final query = data['searchterm'];
    if (query is! String || query.trim().isEmpty) return null;
    final label = data['name'];
    return GifCategory(
      // Tenor libelle ses puces avec le dièse (`#lazy`) ; un tag sans libellé
      // se rabat sur son terme, qui reste lisible.
      label: label is String && label.trim().isNotEmpty
          ? label.trim()
          : '#${query.trim()}',
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
