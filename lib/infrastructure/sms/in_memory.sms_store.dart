import 'dart:async';

import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/model/sms_event.dart';
import 'package:messages/core/domain/services/sms_event.source.dart';
import 'package:uuid/uuid.dart';

/// Stock SMS simulé : ce que le `ContentProvider` Telephony fait sur Android,
/// en mémoire.
///
/// Sert deux besoins :
/// - **les tests**, comme doublure des repositories (pas de mockito) ;
/// - **le dev hors-Android** (macOS, web), où l'app tourne sur des données de
///   démonstration.
///
/// Les fils sont dérivés des messages, exactement comme le fait Android : un
/// `thread_id` est l'identité d'un jeu de destinataires, et son résumé
/// (`snippet`, `date`, compteurs) se recalcule à chaque écriture.
class InMemorySmsStore implements SmsEventSource {
  final List<Message> _messages = [];
  final Map<String, List<Address>> _recipientsByThread = {};
  final StreamController<SmsEvent> _events = StreamController.broadcast();
  final Uuid _uuid = const Uuid();

  /// Simule le cycle `sending → sent → delivered` d'un envoi réel. Désactivé
  /// dans les tests, qui pilotent les transitions à la main.
  final bool simulateDelivery;

  InMemorySmsStore({this.simulateDelivery = false});

  @override
  Stream<SmsEvent> get events => _events.stream;

  List<Message> get messages => List.unmodifiable(_messages);

  /// `thread_id` du jeu de destinataires, créé s'il n'existe pas encore.
  /// L'identité d'un fil est l'ensemble (non ordonné) des clés d'adresses.
  String threadIdFor(List<Address> recipients) {
    final wanted = recipients.map((a) => a.key).toSet();
    for (final entry in _recipientsByThread.entries) {
      final existing = entry.value.map((a) => a.key).toSet();
      if (existing.length == wanted.length && existing.containsAll(wanted)) {
        return entry.key;
      }
    }
    final id = 'thread-${_recipientsByThread.length + 1}';
    _recipientsByThread[id] = List.unmodifiable(recipients);
    return id;
  }

  List<Address> recipientsOf(String threadId) =>
      _recipientsByThread[threadId] ?? const [];

  /// Résumés des fils, du plus récent au plus ancien.
  List<Conversation> conversations() {
    final byThread = <String, List<Message>>{};
    for (final message in _messages) {
      byThread.putIfAbsent(message.threadId, () => []).add(message);
    }

    final conversations = byThread.entries.map((entry) {
      final messages = [...entry.value]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      final last = messages.last;
      return Conversation(
        id: entry.key,
        recipients: recipientsOf(entry.key).isEmpty
            ? [last.address]
            : recipientsOf(entry.key),
        snippet: last.body,
        lastMessageAt: last.sentAt,
        messageCount: messages.length,
        unreadCount: messages.where((m) => m.isUnread).length,
      );
    }).toList();

    conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return conversations;
  }

  Conversation? conversation(String threadId) =>
      conversations().where((c) => c.id == threadId).firstOrNull;

  List<Message> messagesFor(String threadId, {int limit = 500}) {
    final messages = _messages.where((m) => m.threadId == threadId).toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    if (messages.length <= limit) return messages;
    return messages.sublist(messages.length - limit);
  }

  Message? byId(String messageId) =>
      _messages.where((m) => m.id == messageId).firstOrNull;

  List<Message> search(String query, {int limit = 50}) {
    final needle = query.toLowerCase();
    final hits = _messages
        .where((m) => m.body.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return hits.take(limit).toList();
  }

  /// Écrit un message tel quel (import, seed, réception simulée).
  Message insert(Message message) {
    _messages.add(message);
    return message;
  }

  /// Dépose un sortant : il apparaît immédiatement en `sending`.
  Message send({
    required List<Address> recipients,
    required String body,
    int? subscriptionId,
  }) {
    final threadId = threadIdFor(recipients);
    final message = Message(
      id: _uuid.v4(),
      threadId: threadId,
      address: recipients.first,
      body: body,
      sentAt: DateTime.now(),
      direction: MessageDirection.outgoing,
      status: MessageStatus.sending,
      subscriptionId: subscriptionId,
    );
    _messages.add(message);
    if (simulateDelivery) _scheduleDelivery(message.id);
    return message;
  }

  /// Simule l'arrivée d'un SMS : insère l'entrant et pousse l'événement, comme
  /// le ferait le récepteur `SMS_DELIVER`.
  Message receive({
    required Address from,
    required String body,
    DateTime? at,
  }) {
    final message = Message(
      id: _uuid.v4(),
      threadId: threadIdFor([from]),
      address: from,
      body: body,
      sentAt: at ?? DateTime.now(),
      direction: MessageDirection.incoming,
      status: MessageStatus.received,
      read: false,
    );
    _messages.add(message);
    _events.add(MessageReceived(message));
    return message;
  }

  void updateStatus(String messageId, MessageStatus status) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final updated = _messages[index].copyWith(status: status);
    _messages[index] = updated;
    _events.add(
      MessageStatusChanged(
        messageId: updated.id,
        threadId: updated.threadId,
        status: status,
      ),
    );
  }

  void markThreadRead(String threadId) {
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.threadId == threadId && !message.read) {
        _messages[i] = message.copyWith(read: true);
        changed = true;
      }
    }
    if (changed) _events.add(const StoreChanged());
  }

  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    _events.add(const StoreChanged());
  }

  void deleteThread(String threadId) {
    _messages.removeWhere((m) => m.threadId == threadId);
    _recipientsByThread.remove(threadId);
    _events.add(const StoreChanged());
  }

  Future<void> dispose() => _events.close();

  /// Le cheminement d'un envoi réel, en accéléré : accusé de dépôt réseau puis
  /// accusé de remise.
  void _scheduleDelivery(String messageId) {
    Future.delayed(const Duration(milliseconds: 700), () {
      updateStatus(messageId, MessageStatus.sent);
      Future.delayed(const Duration(milliseconds: 1500), () {
        updateStatus(messageId, MessageStatus.delivered);
      });
    });
  }
}
