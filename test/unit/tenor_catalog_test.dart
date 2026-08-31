import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messages/infrastructure/gif/tenor.gif_catalog.service.dart';

import '../helpers/test_logger.dart';

/// Ce que l'app comprend de Tenor, et ce qu'elle lui demande.
///
/// La réponse est lue à la main, comme la charge OTLP de Signoz : c'est le
/// genre de code dont une erreur ne casse aucun écran — la grille reste
/// simplement vide, sans que rien ne dise pourquoi. D'où ces tests, qui lisent
/// la requête réellement posée et la réponse réellement décodée.
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

  TenorGifCatalog catalogOn(http.Client client) =>
      TenorGifCatalog(client: client, apiKey: 'K', logger: testLogger());

  Map<String, Object?> result({
    String id = 'g1',
    String description = 'Happy Dog Day GIF',
    Map<String, Object?>? formats,
  }) => {
    'id': id,
    'content_description': description,
    'media_formats':
        formats ??
        {
          'gif': {
            'url': 'https://media.tenor.com/full.gif',
            'dims': [498, 280],
            'size': 900000,
          },
          'mediumgif': {
            'url': 'https://media.tenor.com/medium.gif',
            'dims': [498, 280],
            'size': 250000,
          },
          'tinygif': {
            'url': 'https://media.tenor.com/tiny.gif',
            'dims': [220, 124],
            'size': 22000,
          },
        },
  };

  group('Ce qui est demandé', () {
    test('la clé, le client et la langue accompagnent chaque appel', () async {
      final http = recorder({'results': []});

      await catalogOn(http.client).featured();

      final query = http.requests.single.queryParameters;
      expect(http.requests.single.host, 'tenor.googleapis.com');
      expect(http.requests.single.path, '/v2/featured');
      expect(query['key'], 'K');
      expect(query['client_key'], 'fr.dtfh.messages');
      expect(query['locale'], 'fr_FR');
      // Un client SMS n'est pas un endroit où l'on tombe sur ce genre de
      // choses par surprise.
      expect(query['contentfilter'], 'high');
    });

    test('seules les quatre déclinaisons GIF sont demandées', () async {
      final http = recorder({'results': []});

      await catalogOn(http.client).featured();

      // Sans ce filtre, Tenor renvoie quatorze déclinaisons par résultat —
      // MP4, WebM, aperçus fixes — pour des adresses qu'on n'ouvrira jamais.
      expect(
        http.requests.single.queryParameters['media_filter'],
        'gif,mediumgif,tinygif,nanogif',
      );
    });

    test('la position de reprise voyage en « pos »', () async {
      final http = recorder({'results': []});

      await catalogOn(http.client).search('chien', cursor: '20');

      expect(http.requests.single.queryParameters['q'], 'chien');
      expect(http.requests.single.queryParameters['pos'], '20');
    });

    test('une recherche vide ne part pas', () async {
      final http = recorder({'results': []});

      final page = await catalogOn(http.client).search('   ');

      expect(page.gifs, isEmpty);
      expect(http.requests, isEmpty);
    });
  });

  group('Ce qui est compris', () {
    test('un résultat porte ses déclinaisons et sa position', () async {
      final http = recorder({
        'results': [result()],
        'next': '20',
      });

      final page = await catalogOn(http.client).featured();

      expect(page.gifs.single.id, 'g1');
      expect(page.gifs.single.description, 'Happy Dog Day GIF');
      expect(page.gifs.single.renditions.length, 3);
      expect(page.hasMore, isTrue);
      // L'aperçu est la déclinaison légère : une grille en fait défiler des
      // dizaines.
      expect(page.gifs.single.preview.url, 'https://media.tenor.com/tiny.gif');
      expect(page.gifs.single.preview.aspectRatio, closeTo(220 / 124, 0.001));
    });

    test('une déclinaison sans poids annoncé est écartée du choix', () async {
      final http = recorder({
        'results': [
          result(
            formats: {
              'gif': {
                'url': 'https://media.tenor.com/full.gif',
                'dims': [498, 280],
              },
              'tinygif': {
                'url': 'https://media.tenor.com/tiny.gif',
                'dims': [220, 124],
                'size': 22000,
              },
            },
          ),
        ],
      });

      final gif = (await catalogOn(http.client).featured()).gifs.single;

      // Croire un poids inconnu « nul » ferait choisir le plein format, et le
      // MMSC refuserait le message.
      expect(gif.bestWithin(292 * 1024)?.url, 'https://media.tenor.com/tiny.gif');
    });

    test('un résultat sans aucune déclinaison est ignoré', () async {
      final http = recorder({
        'results': [
          result(formats: const {}),
          result(id: 'g2'),
        ],
      });

      final page = await catalogOn(http.client).featured();

      // Un résultat inexploitable est un résultat de moins, pas une page
      // perdue.
      expect(page.gifs.map((g) => g.id), ['g2']);
    });

    test('les puces gardent leur libellé et leur terme', () async {
      final http = recorder({
        'tags': [
          {'searchterm': 'paresseux', 'name': '#paresseux'},
          {'searchterm': 'bravo'},
          {'name': '#sans_terme'},
        ],
      });

      final categories = await catalogOn(http.client).categories();

      expect(categories.map((c) => c.label), ['#paresseux', '#bravo']);
      expect(categories.map((c) => c.query), ['paresseux', 'bravo']);
    });
  });

  group('Ce qui ne casse rien', () {
    test('un refus du service rend une page vide', () async {
      final http = recorder({'error': 'quota'}, status: 403);

      expect((await catalogOn(http.client).featured()).gifs, isEmpty);
    });

    test('une réponse illisible rend une page vide', () async {
      final http = recorder('<html>oups</html>');

      expect((await catalogOn(http.client).featured()).gifs, isEmpty);
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
