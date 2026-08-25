import 'package:messages/core/domain/model/address.dart';

/// Un fil de discussion (`thread_id` du stock Telephony), avec ses
/// destinataires et l'aperçu du dernier message.
///
/// Le fil n'embarque pas ses messages : la liste des conversations se contente
/// du résumé que le provider expose (`snippet`, `date`, `message_count`,
/// `read`), et les messages ne sont chargés qu'à l'ouverture du fil.
class Conversation {
  final String id;

  /// Interlocuteurs du fil. Plusieurs entrées ⇒ conversation de groupe.
  final List<Address> recipients;

  /// Début du dernier message, tel que stocké par Android.
  final String snippet;
  final DateTime lastMessageAt;
  final int messageCount;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.recipients,
    required this.snippet,
    required this.lastMessageAt,
    this.messageCount = 0,
    this.unreadCount = 0,
  }) : assert(id != '', 'id cannot be empty'),
       assert(recipients.isNotEmpty, 'a conversation has at least one recipient');

  bool get isGroup => recipients.length > 1;
  bool get hasUnread => unreadCount > 0;

  Address get primaryRecipient => recipients.first;

  Conversation copyWith({
    List<Address>? recipients,
    String? snippet,
    DateTime? lastMessageAt,
    int? messageCount,
    int? unreadCount,
  }) {
    return Conversation(
      id: id,
      recipients: recipients ?? this.recipients,
      snippet: snippet ?? this.snippet,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
