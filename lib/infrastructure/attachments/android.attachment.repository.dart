import 'dart:typed_data';

import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [AttachmentRepository] lisant les parties de `content://mms/part` et les
/// fichiers désignés par un brouillon.
class AndroidAttachmentRepository implements AttachmentRepository {
  final AndroidSmsChannel _channel;

  const AndroidAttachmentRepository(this._channel);

  @override
  Future<Uint8List?> bytesOf(String attachmentId) =>
      _channel.readAttachment(attachmentId);

  @override
  Future<Uint8List?> draftBytesOf(AttachmentDraft draft) =>
      _channel.readAttachmentUri(draft.uri);

  @override
  Future<void> discardDraft(AttachmentDraft draft) async {
    // Une image compressée laisse deux fichiers derrière elle : l'original
    // choisi et la version allégée. Les deux sont à nous, les deux partent.
    await _channel.discardAttachment(draft.uri);
    if (draft.sourceUri != draft.uri) {
      await _channel.discardAttachment(draft.sourceUri);
    }
  }
}
