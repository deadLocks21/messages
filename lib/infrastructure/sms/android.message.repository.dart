import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/services/message.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [MessageRepository] lisant/écrivant `content://sms` via le canal natif.
class AndroidMessageRepository implements MessageRepository {
  final AndroidSmsChannel _channel;

  const AndroidMessageRepository(this._channel);

  @override
  Future<List<Message>> listForThread(String threadId, {int limit = 500}) =>
      _channel.listMessages(threadId, limit: limit);

  @override
  Future<List<Message>> search(String query, {int limit = 50}) =>
      _channel.searchMessages(query, limit: limit);

  @override
  Future<Message?> getById(String messageId) => _channel.getMessage(messageId);

  @override
  Future<Message> send({
    required List<Address> recipients,
    required String body,
    List<AttachmentDraft> attachments = const [],
    int? subscriptionId,
  }) => _channel.sendMessage(
    recipients: recipients,
    body: body,
    attachments: attachments,
    subscriptionId: subscriptionId,
  );

  @override
  Future<Message> resend(String messageId) async {
    final original = await _channel.getMessage(messageId);
    if (original == null) throw const MessageNotFoundException();
    // La tentative en échec est retirée du stock avant la nouvelle : sinon le
    // fil garde une bulle « non distribué » orpheline juste au-dessus.
    await _channel.deleteMessage(messageId);
    return _channel.sendMessage(
      recipients: [original.address],
      body: original.body,
      attachments: original.attachments.map(_asDraft).toList(),
      subscriptionId: original.subscriptionId,
    );
  }

  /// Une partie déjà écrite, relue comme un brouillon à réémettre.
  ///
  /// Le stock l'expose sous `content://mms/part/<_id>` : le natif sait lire
  /// cette URI comme n'importe quelle autre, ce qui évite de recopier les
  /// octets dans un fichier temporaire pour les lui redonner.
  AttachmentDraft _asDraft(Attachment attachment) => AttachmentDraft(
    id: attachment.id,
    uri: 'content://mms/part/${attachment.id}',
    mimeType: attachment.mimeType,
    fileName: attachment.fileName ?? attachment.id,
    byteSize: attachment.byteSize,
    width: attachment.width,
    height: attachment.height,
  );

  @override
  Future<void> delete(String messageId) => _channel.deleteMessage(messageId);
}
