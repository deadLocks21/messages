import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';

/// Événement poussé par le stock SMS. Classe scellée : tout consommateur en
/// fait un `switch` exhaustif.
sealed class SmsEvent {
  const SmsEvent();
}

/// Un SMS vient d'arriver (`SMS_DELIVER`, l'app étant celle par défaut).
class MessageReceived extends SmsEvent {
  final Message message;
  const MessageReceived(this.message);
}

/// Suite d'un envoi : accusé de dépôt réseau, puis accusé de remise.
class MessageStatusChanged extends SmsEvent {
  final String messageId;
  final String threadId;
  final MessageStatus status;
  const MessageStatusChanged({
    required this.messageId,
    required this.threadId,
    required this.status,
  });
}

/// Le stock a bougé pour une raison non détaillée (suppression, marquage lu par
/// une autre app, import…). Le consommateur recharge simplement ses vues.
class StoreChanged extends SmsEvent {
  const StoreChanged();
}
