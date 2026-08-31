import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/media_downloader.service.dart';
import 'package:messages/infrastructure/attachments/sample_image.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';
import 'package:uuid/uuid.dart';

/// Rapatriement simulé : rien ne descend du réseau.
///
/// Ce qu'il dépose est un PNG uni — de vrais octets, décodables, comme ceux du
/// sélecteur simulé : la vignette du plateau, l'envoi et la bulle sont ainsi
/// éprouvés de bout en bout, ce qu'un tableau d'octets bidon ne ferait pas. Le
/// type annoncé reste celui demandé (`image/gif`) : c'est lui que suit
/// l'aiguillage MMS, et c'est lui qu'on veut voir passer.
///
/// [failNext] simule l'adresse périmée ou le réseau absent — le cas que l'UI
/// doit annoncer plutôt que de laisser un plateau vide.
class InMemoryMediaDownloader implements MediaDownloader {
  final InMemorySmsStore _store;
  final Uuid _uuid = const Uuid();

  /// Adresses demandées, dans l'ordre — ce que vérifient les tests.
  final List<String> downloaded = [];

  bool failNext;

  InMemoryMediaDownloader(this._store, {this.failNext = false});

  @override
  Future<AttachmentDraft> download(
    String url, {
    required String mimeType,
    required String fileName,
  }) async {
    downloaded.add(url);
    if (failNext) {
      failNext = false;
      throw const MediaDownloadFailedException();
    }

    const width = 240;
    const height = 180;
    final bytes = SampleImage.solid(
      width: width,
      height: height,
      argb: 0xFF8A5100,
    );
    final draft = AttachmentDraft(
      id: _uuid.v4(),
      uri: 'memory://$fileName',
      mimeType: mimeType,
      fileName: fileName,
      byteSize: bytes.length,
      width: width,
      height: height,
    );
    _store.registerDraft(draft, bytes);
    return draft;
  }
}
