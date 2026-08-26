import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

/// [ConversationRepository] adossé au stock simulé. Doublure des tests et
/// implémentation de secours hors-Android.
class InMemoryConversationRepository implements ConversationRepository {
  final InMemorySmsStore _store;

  const InMemoryConversationRepository(this._store);

  @override
  Future<List<Conversation>> listAll() async => _store.conversations();

  @override
  Future<Conversation?> getById(String threadId) async =>
      _store.conversation(threadId);

  @override
  Future<String> resolveThreadId(List<Address> recipients) async =>
      _store.threadIdFor(recipients);

  @override
  Future<bool> markRead(String threadId) async => _store.markThreadRead(threadId);

  @override
  Future<void> delete(String threadId) async => _store.deleteThread(threadId);
}
