import 'package:messages/core/domain/services/attachment_opener.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [AttachmentOpener] adossé aux intents d'Android.
///
/// La partie est recopiée côté natif avant d'être passée : `content://mms/part`
/// n'est lisible que par l'app SMS par défaut, et l'application appelée se
/// verrait refuser la lecture (cf. `AttachmentOpener.kt`).
class AndroidAttachmentOpener implements AttachmentOpener {
  final AndroidSmsChannel _channel;

  const AndroidAttachmentOpener(this._channel);

  @override
  Future<bool> open(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  }) => _channel.openAttachment(
    attachmentId,
    mimeType: mimeType,
    fileName: fileName,
  );

  @override
  Future<bool> save(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  }) => _channel.saveAttachment(
    attachmentId,
    mimeType: mimeType,
    fileName: fileName,
  );
}
