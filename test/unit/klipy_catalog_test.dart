import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messages/infrastructure/gif/klipy.gif_catalog.service.dart';

import '../helpers/test_logger.dart';

/// Ce que l'app comprend de Klipy, et ce qu'elle lui demande.
///
/// La réponse est lue à la main, comme la charge OTLP de Signoz : c'est le
/// genre de code dont une erreur ne casse aucun écran — la grille reste
/// simplement vide, sans que rien ne dise pourquoi. D'où ces tests, qui lisent
/// la requête réellement posée et la réponse réellement décodée.
///
/// Les formes de réponse sont celles relevées sur l'API, clé de test en main.
void main() {
  ({http.Client client, List<Uri> requests}) recorder(
    Object body, {
    int status = 200,
  }) {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        body is String ? body : jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (client: client, requests: requests);
  }

  KlipyGifCatalog catalogOn(http.Client client) =>
      KlipyGifCatalog(client: client, apiKey: 'K', logger: testLogger());

  /// Une taille, telle que Klipy la sert : cinq formats par palier.
  Map<String, Object?> tier({
    required int width,
    required int height,
    required int gifSize,
    int? webpSize,
  }) => {
    'gif': {
      'url': 'https://static.klipy.com/$gifSize.gif',
      'width': width,
      'height': height,
      'size': gifSize,
    },
    'webp': {
      'url': 'https://static.klipy.com/$gifSize.webp',
      'width': width,
      'height': height,
      'size': webpSize ?? gifSize ~/ 3,
    },
  };

  Map<String, Object?> item({
    Object id = 1293093275580130,
    String title = 'Buford the Dog',
    String? blur = 'data:image/jpeg;base64,/9j/AAAA',
    Map<String, Object?>? file,
  }) => {
    'id': id,
    'slug': 'buford-the-dog',
    'title': title,
    'type': 'gif',
    'blur_preview': ?blur,
    'file':
        file ??
        {
          'hd': tier(width: 441, height: 486, gifSize: 900000),
          'md': tier(width: 374, height: 374, gifSize: 400000),
          'sm': tier(width: 192, height: 212, gifSize: 250000),
          'xs': tier(width: 90, height: 90, gifSize: 40000),
        },
  };

  Object page(List<Object> items, {bool hasNext = false}) => {
    'result': true,
    'data': {
      'data': items,
      'current_page': 1,
      'per_page': 20,
      'has_next': hasNext,
    },
  };

  group('Ce qui est demandé', () {
    test('la clé voyage dans le chemin, jamais en paramètre', () async {
      final klipy = recorder(page(const []));

      await catalogOn(klipy.client).featured();

      final uri = klipy.requests.single;
      expect(uri.host, 'api.klipy.com');
      expect(uri.path, '/api/v1/K/gifs/trending');
      // C'est ainsi que Klipy la veut — et c'est pour ça qu'aucun log ne porte
      // l'URL.
      expect(uri.queryParameters.containsKey('key'), isFalse);
      expect(uri.queryParameters['locale'], 'fr_FR');
    });

    test('la pagination est un numéro de page', () async {
      final klipy = recorder(page(const []));

      await catalogOn(klipy.client).search('chien', cursor: '3');

      expect(klipy.requests.single.path, '/api/v1/K/gifs/search');
      expect(klipy.requests.single.queryParameters['q'], 'chien');
      expect(klipy.requests.single.queryParameters['page'], '3');
    });

    test('la première page est demandée sans position', () async {
      final klipy = recorder(page(const []));

      await catalogOn(klipy.client).featured();

      expect(klipy.requests.single.queryParameters['page'], '1');
    });

    test('une recherche vide ne part pas', () async {
      final klipy = recorder(page(const []));

      expect((await catalogOn(klipy.client).search('   ')).gifs, isEmpty);
      expect(klipy.requests, isEmpty);
    });
  });

  group('Ce qui est compris', () {
    test('les quatre tailles deviennent les déclinaisons joignables', () async {
      final klipy = recorder(page([item()]));

      final gif = (await catalogOn(klipy.client).featured()).gifs.single;

      expect(gif.renditions.map((r) => r.byteSize), [
        900000,
        400000,
        250000,
        40000,
      ]);
      // Toutes en GIF : le MP4 de Klipy pèse moins, mais chez le destinataire
      // ce ne serait plus un GIF, ce serait une vidéo.
      expect(gif.renditions.every((r) => r.url.endsWith('.gif')), isTrue);
    });

    test('l\'aperçu est le WebP de taille moyenne', () async {
      final klipy = recorder(page([item()]));

      final gif = (await catalogOn(klipy.client).featured()).gifs.single;

      // Le même dessin y tient en trois fois moins d'octets, Flutter l'anime
      // aussi bien, et rien ne part de l'aperçu.
      expect(gif.preview.url, endsWith('.webp'));
      expect(gif.preview.width, 192);
    });

    test('l\'identifiant numérique devient une chaîne', () async {
      final klipy = recorder(page([item()]));

      final gif = (await catalogOn(klipy.client).featured()).gifs.single;

      expect(gif.id, '1293093275580130');
    });

    test('l\'image floue est reprise telle quelle', () async {
      final klipy = recorder(page([item()]));

      final gif = (await catalogOn(klipy.client).featured()).gifs.single;

      expect(gif.blurPreview, startsWith('data:image/jpeg;base64,'));
    });

    test('« has_next » devient la page suivante', () async {
      final withNext = recorder(page([item()], hasNext: true));
      final without = recorder(page([item()]));

      expect((await catalogOn(withNext.client).featured()).hasMore, isTrue);
      expect((await catalogOn(without.client).featured()).hasMore, isFalse);
    });

    test('une taille sans poids annoncé est écartée du choix', () async {
      final klipy = recorder(
        page([
          item(
            file: {
              'hd': {
                'gif': {
                  'url': 'https://static.klipy.com/hd.gif',
                  'width': 441,
                  'height': 486,
                },
              },
              'xs': tier(width: 90, height: 90, gifSize: 40000),
            },
          ),
        ]),
      );

      final gif = (await catalogOn(klipy.client).featured()).gifs.single;

      // Croire un poids inconnu « nul » ferait choisir la plus grande, et le
      // MMSC refuserait le message.
      expect(gif.bestWithin(292 * 1024)?.byteSize, 40000);
    });

    test('un résultat sans aucune taille est ignoré', () async {
      final klipy = recorder(
        page([
          item(file: const {}),
          item(id: 42),
        ]),
      );

      final gifs = (await catalogOn(klipy.client).featured()).gifs;

      // Un résultat inexploitable est un résultat de moins, pas une page
      // perdue.
      expect(gifs.map((g) => g.id), ['42']);
    });

    test('les puces portent le dièse que Klipy ne met pas', () async {
      final klipy = recorder({
        'result': true,
        'data': {
          'locale': 'fr_FR',
          'categories': [
            {'category': 'mdr', 'query': 'mdr'},
            {'category': 'désolé', 'query': 'désolé'},
          ],
        },
      });

      final categories = await catalogOn(klipy.client).categories();

      expect(categories.map((c) => c.label), ['#mdr', '#désolé']);
      expect(categories.map((c) => c.query), ['mdr', 'désolé']);
    });
  });

  group('Ce qui ne casse rien', () {
    test('un refus applicatif rend une page vide', () async {
      // `result: false` avec un code HTTP 200 : Klipy distingue les deux, nous
      // aussi.
      final klipy = recorder({'result': false, 'data': null});

      expect((await catalogOn(klipy.client).featured()).gifs, isEmpty);
    });

    test('un refus HTTP rend une page vide', () async {
      final klipy = recorder({'result': false}, status: 403);

      expect((await catalogOn(klipy.client).featured()).gifs, isEmpty);
    });

    test('une réponse illisible rend une page vide', () async {
      expect(
        (await catalogOn(recorder('<html>oups</html>').client).featured()).gifs,
        isEmpty,
      );
    });

    test('le réseau absent rend une page vide', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('offline'),
      );

      // Hors ligne, il n'y a pas de GIF — ce n'est pas une panne de l'app, et
      // la grille le dit à sa façon.
      expect((await catalogOn(client).featured()).gifs, isEmpty);
    });
  });
}
