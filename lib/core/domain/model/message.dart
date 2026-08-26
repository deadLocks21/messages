import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/enums.dart';

/// Un message du stock Telephony : un SMS, ou un MMS dès qu'il porte des
/// pièces jointes.
///
/// [id] est le `_id` du provider pour un message déjà écrit, ou un UUID local
/// pour un envoi optimiste pas encore inséré. [threadId] est le `thread_id`
/// calculé par Android à partir des destinataires.
class Message {
  final String id;
  final String threadId;

  /// Interlocuteur : l'expéditeur pour un entrant, le destinataire pour un
  /// sortant.
  final Address address;
  final String body;
  final DateTime sentAt;
  final MessageDirection direction;
  final MessageStatus status;
  final bool read;

  /// Identifiant d'abonnement (SIM) utilisé. Null quand l'appareil est mono-SIM
  /// ou que le stock ne le renseigne pas.
  final int? subscriptionId;

  /// Parties non textuelles du message. Vide pour un SMS — c'est d'ailleurs ce
  /// qui distingue les deux : un message *est* un MMS parce qu'il en a.
  final List<Attachment> attachments;

  Message({
    required this.id,
    required this.threadId,
    required this.address,
    required this.body,
    required this.sentAt,
    required this.direction,
    required this.status,
    this.read = true,
    this.subscriptionId,
    this.attachments = const [],
  }) : assert(id != '', 'id cannot be empty'),
       assert(threadId != '', 'threadId cannot be empty');

  bool get isOutgoing => direction.isOutgoing;

  /// Un message porté par le MMS plutôt que par le SMS.
  bool get isMms => attachments.isNotEmpty;

  /// Un entrant non lu : ce qui fait grossir le compteur d'une conversation.
  bool get isUnread => !read && direction == MessageDirection.incoming;

  Message copyWith({
    String? id,
    String? threadId,
    String? body,
    DateTime? sentAt,
    MessageStatus? status,
    bool? read,
    int? subscriptionId,
    List<Attachment>? attachments,
  }) {
    return Message(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      address: address,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      direction: direction,
      status: status ?? this.status,
      read: read ?? this.read,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
