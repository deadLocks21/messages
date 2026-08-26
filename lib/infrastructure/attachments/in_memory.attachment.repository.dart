import 'dart:typed_data';

import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

/// [AttachmentRepository] adossé au stock simulé.
class InMemoryAttachmentRepository implements AttachmentRepository {
  final InMemorySmsStore _store;

  const InMemoryAttachmentRepository(this._store);

  @override
  Future<Uint8List?> bytesOf(String attachmentId) async =>
      _store.bytesOf(attachmentId);

  @override
  Future<Uint8List?> draftBytesOf(AttachmentDraft draft) async =>
      _store.draftBytesOf(draft.id);

  @override
  Future<void> discardDraft(AttachmentDraft draft) async =>
      _store.discardDraft(draft.id);
}
