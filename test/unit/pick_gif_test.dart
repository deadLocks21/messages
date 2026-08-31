import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/usecases/pick_gif.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/gif.dart';
import 'package:messages/core/domain/services/media_downloader.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/logger/in_memory.logger.service.dart';

import '../helpers/test_logger.dart';

/// Un rapatriement qui note ce qu'on lui demande et rend ce qu'on lui dit.
///
/// Ni le stock ni les octets n'ont d'intérêt ici : ce qui se joue, c'est
/// **quelle adresse** est descendue du réseau, et sous quel nom.
class _Downloader implements MediaDownloader {
  final List<String> urls = [];
  final List<String> names = [];
  int Function(String url) sizeOf;
  bool fails;

  _Downloader({int size = 1024}) : sizeOf = ((_) => size), fails = false;

  @override
  Future<AttachmentDraft> download(
    String url, {
    required String mimeType,
    required String fileName,
  }) async {
    urls.add(url);
    names.add(fileName);
    if (fails) throw const MediaDownloadFailedException();
    return AttachmentDraft(
      id: 'draft',
      uri: 'file:///cache/gifs/$fileName',
      mimeType: mimeType,
      fileName: fileName,
      byteSize: sizeOf(url),
    );
  }
}

void main() {
  late _Downloader downloader;
  late InMemoryMmsConfiguration carrier;
  late InMemoryLoggerService logs;

  setUp(() {
    downloader = _Downloader();
    carrier = InMemoryMmsConfiguration();
    logs = InMemoryLoggerService();
  });

  PickGifUseCase usecase() => PickGifUseCase(
    downloader: downloader,
    configuration: carrier,
    logger: testLogger(logs),
  );

  GifRendition rendition(String name, int bytes) => GifRendition(
    url: 'https://media.example/$name.gif',
    width: 400,
    height: 300,
    byteSize: bytes,
  );

  Gif gif({String description = 'Happy Dog Day GIF'}) => Gif(
    id: 'g1',
    description: description,
    preview: rendition('tiny', 22 * 1024),
    renditions: [
      rendition('full', 900 * 1024),
      rendition('medium', 250 * 1024),
      rendition('tiny', 22 * 1024),
    ],
  );

  test('ne télécharge que la déclinaison qui tient dans le budget', () async {
    await usecase().execute(gif());

    // Le budget par défaut (300 ko moins l'enveloppe) écarte le plein format :
    // il ne descend jamais du réseau, et c'est bien l'intérêt de choisir
    // avant plutôt que de rattraper après.
    expect(downloader.urls, ['https://media.example/medium.gif']);
  });

  test('suit le budget de l\'opérateur, pas une constante', () async {
    carrier.value = const MmsLimits(maxTotalBytes: 64 * 1024);

    await usecase().execute(gif());

    expect(downloader.urls, ['https://media.example/tiny.gif']);
  });

  test('refuse quand aucune déclinaison ne tient', () async {
    carrier.value = const MmsLimits(maxTotalBytes: 12 * 1024);

    await expectLater(
      usecase().execute(gif()),
      throwsA(isA<AttachmentTooLargeException>()),
    );
    // Rien n'est descendu : un refus, ce n'est pas un téléchargement pour rien.
    expect(downloader.urls, isEmpty);
    expect(logs.records.last.attributes['attachment.reason'], 'no_rendition_fits');
  });

  test('refuse aussi quand le fichier reçu dépasse ce qui était annoncé', () async {
    downloader.sizeOf = (_) => 400 * 1024;

    await expectLater(
      usecase().execute(gif()),
      throwsA(isA<AttachmentTooLargeException>()),
    );
    expect(
      logs.records.last.attributes['attachment.reason'],
      'downloaded_too_large',
    );
  });

  test('nomme le fichier d\'après ce que le GIF montre', () async {
    await usecase().execute(gif());

    // `happy-dog-day-gif.gif` se retrouve dans une galerie ; `AAAADS8n1s.gif`
    // non.
    expect(downloader.names, ['happy-dog-day-gif.gif']);
  });

  test('retombe sur un nom générique quand il n\'y a rien à raboter', () async {
    await usecase().execute(gif(description: '🐕'));

    expect(downloader.names, ['gif.gif']);
  });

  test('journalise l\'échec du réseau et le laisse remonter', () async {
    downloader.fails = true;

    await expectLater(
      usecase().execute(gif()),
      throwsA(isA<MediaDownloadFailedException>()),
    );
    expect(logs.records.last.message, 'gif.download_failed');
  });
}
