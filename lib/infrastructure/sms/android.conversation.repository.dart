import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [ConversationRepository] lisant `content://mms-sms/conversations` via le
/// canal natif.
class AndroidConversationRepository implements ConversationRepository {
  final AndroidSmsChannel _channel;

  /// Destinataires des fils résolus pendant cette session.
  ///
  /// Un fil qui vient d'être créé pour ouvrir une conversation n'a aucun
  /// message, et relire ses destinataires dans le stock système peut revenir
  /// vide : les tables `threads` / `canonical-addresses` ne sont pas lisibles
  /// partout de la même façon, et le provider peut purger un fil vide. Or c'est
  /// nous qui venons de les donner : les garder évite d'ouvrir un fil dans
  /// lequel on ne peut pas écrire.
  final Map<String, List<Address>> _resolved = {};

  AndroidConversationRepository(this._channel);

  @override
  Future<List<Conversation>> listAll() => _channel.listConversations();

  @override
  Future<Conversation?> getById(String threadId) =>
      _channel.getConversation(threadId);

  @override
  Future<String> resolveThreadId(List<Address> recipients) async {
    final threadId = await _channel.resolveThreadId(recipients);
    _resolved[threadId] = List.unmodifiable(recipients);
    return threadId;
  }

  @override
  Future<List<Address>> recipientsOf(String threadId) async {
    final fromStore = await _channel.recipientsOf(threadId);
    if (fromStore.isNotEmpty) return fromStore;
    return _resolved[threadId] ?? const [];
  }

  @override
  Future<bool> markRead(String threadId) => _channel.markThreadRead(threadId);

  @override
  Future<void> delete(String threadId) async {
    await _channel.deleteThread(threadId);
    _resolved.remove(threadId);
  }
}
