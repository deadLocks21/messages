import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/media_downloader.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [MediaDownloader] adossé au pont natif.
///
/// Le téléchargement est confié au natif plutôt que fait en Dart pour la
/// raison qui vaut partout ailleurs dans l'app : **les octets ne traversent
/// pas le canal**. Le fichier doit de toute façon finir dans le cache derrière
/// le `FileProvider` — c'est de là que l'envoi du MMS le relira — et l'y écrire
/// depuis Dart demanderait de faire remonter le média pour le redescendre
/// aussitôt.
class AndroidMediaDownloader implements MediaDownloader {
  final AndroidSmsChannel _channel;

  const AndroidMediaDownloader(this._channel);

  @override
  Future<AttachmentDraft> download(
    String url, {
    required String mimeType,
    required String fileName,
  }) => _channel.downloadMedia(
    url,
    mimeType: mimeType,
    fileName: fileName,
  );
}
