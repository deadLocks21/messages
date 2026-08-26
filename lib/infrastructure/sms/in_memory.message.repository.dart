import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/services/message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

/// [MessageRepository] adossé au stock simulé.
class InMemoryMessageRepository implements MessageRepository {
  final InMemorySmsStore _store;

  const InMemoryMessageRepository(this._store);

  @override
  Future<List<Message>> listForThread(String threadId, {int limit = 500}) async =>
      _store.messagesFor(threadId, limit: limit);

  @override
  Future<List<Message>> search(String query, {int limit = 50}) async =>
      _store.search(query, limit: limit);

  @override
  Future<Message?> getById(String messageId) async => _store.byId(messageId);

  @override
  Future<Message> send({
    required List<Address> recipients,
    required String body,
    List<AttachmentDraft> attachments = const [],
    int? subscriptionId,
  }) async {
    return _store.send(
      recipients: recipients,
      body: body,
      attachments: attachments,
      subscriptionId: subscriptionId,
    );
  }

  @override
  Future<Message> resend(String messageId) async {
    final original = _store.byId(messageId);
    if (original == null) throw const MessageNotFoundException();
    // La tentative en échec disparaît : le fil ne doit pas garder deux bulles
    // identiques dont une barrée.
    _store.deleteMessage(messageId);
    return _store.send(
      recipients: _store.recipientsOf(original.threadId).isEmpty
          ? [original.address]
          : _store.recipientsOf(original.threadId),
      body: original.body,
      attachments: original.attachments.map(_store.draftFrom).toList(),
      subscriptionId: original.subscriptionId,
    );
  }

  @override
  Future<void> delete(String messageId) async => _store.deleteMessage(messageId);
}
