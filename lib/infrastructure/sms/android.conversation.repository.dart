import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [ConversationRepository] lisant `content://mms-sms/conversations` via le
/// canal natif.
class AndroidConversationRepository implements ConversationRepository {
  final AndroidSmsChannel _channel;

  const AndroidConversationRepository(this._channel);

  @override
  Future<List<Conversation>> listAll() => _channel.listConversations();

  @override
  Future<Conversation?> getById(String threadId) =>
      _channel.getConversation(threadId);

  @override
  Future<String> resolveThreadId(List<Address> recipients) =>
      _channel.resolveThreadId(recipients);

  @override
  Future<void> markRead(String threadId) => _channel.markThreadRead(threadId);

  @override
  Future<void> delete(String threadId) => _channel.deleteThread(threadId);
}
