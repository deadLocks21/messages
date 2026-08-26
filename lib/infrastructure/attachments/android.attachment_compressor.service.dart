import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_compressor.service.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [AttachmentCompressor] adossé au décodeur d'images d'Android.
class AndroidAttachmentCompressor implements AttachmentCompressor {
  final AndroidSmsChannel _channel;

  const AndroidAttachmentCompressor(this._channel);

  @override
  Future<AttachmentDraft?> compress(
    AttachmentDraft draft, {
    required int targetBytes,
  }) => _channel.compressAttachment(draft, targetBytes: targetBytes);
}
