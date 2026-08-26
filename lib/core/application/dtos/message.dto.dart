import 'package:messages/core/application/dtos/attachment.dto.dart';
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

  /// Pièces jointes du message. Vide pour un SMS.
  final List<AttachmentDto> attachments;

  const MessageDto({
    required this.id,
    required this.threadId,
    required this.body,
    required this.sentAt,
    required this.isOutgoing,
    required this.status,
    required this.address,
    this.senderName,
    this.attachments = const [],
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
      attachments: message.attachments.map(AttachmentDto.fromDomain).toList(),
    );
  }

  bool get hasAttachments => attachments.isNotEmpty;

  /// Ce qu'on montre du message là où il n'y a de place que pour une ligne :
  /// résumé de fil, notification, résultat de recherche.
  ///
  /// Une pièce jointe sans texte n'a rien à afficher — on la nomme par sa
  /// nature (« Photo »), comme le fait l'app d'origine, plutôt que de laisser
  /// une ligne vide.
  String get previewText {
    if (attachments.isEmpty) return body;
    final label = attachments.length == 1
        ? attachments.first.previewLabel
        : '${attachments.length} pièces jointes';
    return body.isEmpty ? label : '$label · $body';
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
