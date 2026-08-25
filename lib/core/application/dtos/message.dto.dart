import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';

/// Un message prêt à l'affichage.
class MessageDto {
  final String id;
  final String threadId;
  final String body;
  final DateTime sentAt;
  final bool isOutgoing;
  final MessageStatus status;

  /// Adresse brute de l'interlocuteur (pour « Détails » et le renvoi).
  final String address;

  /// Nom de l'expéditeur, utile uniquement dans un fil de groupe.
  final String? senderName;

  const MessageDto({
    required this.id,
    required this.threadId,
    required this.body,
    required this.sentAt,
    required this.isOutgoing,
    required this.status,
    required this.address,
    this.senderName,
  });

  factory MessageDto.fromDomain(Message message, {String? senderName}) {
    return MessageDto(
      id: message.id,
      threadId: message.threadId,
      body: message.body,
      sentAt: message.sentAt,
      isOutgoing: message.isOutgoing,
      status: message.status,
      address: message.address.raw,
      senderName: senderName,
    );
  }

  /// Libellé d'état affiché sous la dernière bulle envoyée.
  String get statusLabel => switch (status) {
    MessageStatus.sending => 'Envoi…',
    MessageStatus.sent => 'Envoyé',
    MessageStatus.delivered => 'Distribué',
    MessageStatus.failed => 'Non distribué',
    MessageStatus.received => 'Reçu',
  };
}
