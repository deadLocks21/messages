import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Réémet un message en échec. Le message d'origine est remplacé par sa
/// nouvelle tentative pour que le fil ne garde pas deux bulles identiques.
class ResendMessageUseCase {
  final MessageRepository _messages;

  const ResendMessageUseCase(this._messages);

  Future<MessageDto> execute(String messageId) async =>
      MessageDto.fromDomain(await _messages.resend(messageId));
}
