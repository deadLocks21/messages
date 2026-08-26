import 'dart:async';
import 'dart:typed_data';

import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
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

  /// Contenu des pièces jointes, par identifiant de partie. Le vrai stock les
  /// garde dans des fichiers ; ici, en mémoire.
  final Map<String, Uint8List> _attachmentBytes = {};

  /// Contenu des pièces jointes encore en rédaction, par identifiant de
  /// brouillon — ce que le sélecteur a produit et que l'envoi consommera.
  final Map<String, Uint8List> _draftBytes = {};
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
        lastAttachmentKind: last.attachments.firstOrNull?.kind,
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
  ///
  /// Les brouillons de pièces jointes deviennent des pièces jointes du stock —
  /// c'est ce que fait Android en écrivant les parties du MMS, en gardant leur
  /// contenu accessible par leur nouvel identifiant.
  Message send({
    required List<Address> recipients,
    required String body,
    List<AttachmentDraft> attachments = const [],
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
      attachments: attachments.map(_store).toList(),
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
    List<Attachment> attachments = const [],
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
      attachments: attachments,
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

  bool markThreadRead(String threadId) {
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.threadId == threadId && !message.read) {
        _messages[i] = message.copyWith(read: true);
        changed = true;
      }
    }
    if (changed) _events.add(const StoreChanged());
    return changed;
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

  /// Déclare un brouillon et son contenu : ce que produit le sélecteur
  /// simulé, en attendant l'envoi.
  void registerDraft(AttachmentDraft draft, Uint8List bytes) =>
      _draftBytes[draft.id] = bytes;

  Uint8List? draftBytesOf(String draftId) => _draftBytes[draftId];

  /// Un brouillon retiré du plateau libère son contenu.
  void discardDraft(String draftId) => _draftBytes.remove(draftId);

  /// Une pièce jointe du stock, relue comme un brouillon — ce dont a besoin le
  /// renvoi d'un MMS en échec.
  AttachmentDraft draftFrom(Attachment attachment) {
    final draft = AttachmentDraft(
      id: 'draft-${_uuid.v4()}',
      uri: 'memory://${attachment.id}',
      mimeType: attachment.mimeType,
      fileName: attachment.fileName ?? attachment.id,
      byteSize: attachment.byteSize,
      width: attachment.width,
      height: attachment.height,
    );
    final bytes = _attachmentBytes[attachment.id];
    if (bytes != null) _draftBytes[draft.id] = bytes;
    return draft;
  }

  /// Octets d'une pièce jointe du stock, servis à l'UI pour sa vignette.
  Uint8List? bytesOf(String attachmentId) => _attachmentBytes[attachmentId];

  /// Dépose un contenu pour une pièce jointe déjà construite (seed, réception
  /// simulée).
  void putAttachmentBytes(String attachmentId, Uint8List bytes) =>
      _attachmentBytes[attachmentId] = bytes;

  Future<void> dispose() => _events.close();

  /// Écrit un brouillon dans le stock : nouvel identifiant, contenu conservé.
  Attachment _store(AttachmentDraft draft) {
    final attachment = Attachment(
      id: 'part-${_uuid.v4()}',
      mimeType: draft.mimeType,
      fileName: draft.fileName,
      byteSize: draft.byteSize,
      width: draft.width,
      height: draft.height,
    );
    final bytes = _draftBytes[draft.id];
    if (bytes != null) _attachmentBytes[attachment.id] = bytes;
    return attachment;
  }

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
