import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/gif.dart';

/// Le choix de la taille d'un GIF, qui est **tout** ce qui distingue son envoi
/// de celui d'une photo.
///
/// Une photo trop lourde se rattrape : on la ré-encode. Un GIF, non — le
/// ré-encoder le figerait. Sa taille se choisit donc parmi les déclinaisons du
/// catalogue, avant tout téléchargement, et c'est ce que ces tests fixent.
void main() {
  GifRendition rendition(int bytes, {int width = 400, int height = 300}) =>
      GifRendition(
        url: 'https://media.example/$bytes.gif',
        width: width,
        height: height,
        byteSize: bytes,
      );

  Gif gifOf(List<int> sizes) => Gif(
    id: 'g1',
    description: 'Happy Dog Day GIF',
    preview: rendition(sizes.last),
    renditions: sizes.map(rendition).toList(),
  );

  group('Choisir une déclinaison', () {
    test('prend la plus belle qui tienne dans le budget', () {
      final gif = gifOf([900 * 1024, 250 * 1024, 40 * 1024]);

      expect(gif.bestWithin(292 * 1024)?.byteSize, 250 * 1024);
    });

    test('descend d\'un cran quand l\'opérateur est avare', () {
      final gif = gifOf([900 * 1024, 250 * 1024, 40 * 1024]);

      expect(gif.bestWithin(56 * 1024)?.byteSize, 40 * 1024);
    });

    test('ne rend rien quand même la plus petite déborde', () {
      final gif = gifOf([900 * 1024, 250 * 1024, 40 * 1024]);

      // Un refus franc plutôt qu'un MMS que le MMSC rejettera : à ce
      // moment-là, l'utilisateur peut encore choisir un autre GIF.
      expect(gif.bestWithin(10 * 1024), isNull);
    });

    test('accepte une déclinaison pile au budget', () {
      final gif = gifOf([300 * 1024, 100 * 1024]);

      expect(gif.bestWithin(300 * 1024)?.byteSize, 300 * 1024);
    });

    test('classe les déclinaisons de la plus lourde à la plus légère', () {
      // L'ordre du catalogue n'est pas garanti : c'est l'entité qui le pose,
      // sinon « la plus belle qui tienne » dépendrait de l'ordre de la réponse.
      final gif = gifOf([40 * 1024, 900 * 1024, 250 * 1024]);

      expect(
        gif.renditions.map((r) => r.byteSize),
        [900 * 1024, 250 * 1024, 40 * 1024],
      );
    });
  });

  group('Un GIF ne se comprime pas', () {
    AttachmentDraft draftOf(String mimeType) => AttachmentDraft(
      id: 'd1',
      uri: 'file:///tmp/a',
      mimeType: mimeType,
      fileName: 'a',
      byteSize: 10,
    );

    test('alors qu\'il est bien une image', () {
      final gif = draftOf('image/gif');

      expect(gif.kind, AttachmentKind.image);
      // Le compresseur ré-encode en JPEG : d'un GIF, il ne resterait qu'une
      // image fixe.
      expect(gif.isCompressible, isFalse);
    });

    test('là où un JPEG et un PNG le restent', () {
      expect(draftOf('image/jpeg').isCompressible, isTrue);
      expect(draftOf('image/png').isCompressible, isTrue);
    });

    test('quelle que soit la casse du type annoncé', () {
      expect(draftOf('IMAGE/GIF').isCompressible, isFalse);
    });
  });

  group('Une page de résultats', () {
    test('dit qu\'il reste à défiler quand elle porte une position', () {
      expect(GifPage(gifs: [gifOf([100])], cursor: '20').hasMore, isTrue);
    });

    test('s\'arrête sur une position absente ou vide', () {
      expect(GifPage(gifs: [gifOf([100])]).hasMore, isFalse);
      expect(GifPage(gifs: [gifOf([100])], cursor: '').hasMore, isFalse);
    });
  });
}
