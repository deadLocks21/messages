import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Réémet un message en échec. Le message d'origine est remplacé par sa
/// nouvelle tentative pour que le fil ne garde pas deux bulles identiques.
class ResendMessageUseCase {
  final MessageRepository _messages;
  final LoggerApplicationService _logger;

  const ResendMessageUseCase(
    this._messages, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  Future<MessageDto> execute(String messageId) async {
    // Un renvoi dit deux choses à la fois : que l'envoi initial a échoué, et
    // que l'utilisateur a dû s'en occuper lui-même. Le compter, c'est mesurer
    // la fiabilité réelle de l'envoi côté téléphone.
    try {
      final resent = await _messages.resend(messageId);
      await _logger.info(
        'message.resent',
        attrs: {'message.id': resent.id, 'thread.id': resent.threadId},
      );
      return MessageDto.fromDomain(resent);
    } catch (e, stack) {
      await _logger.error(
        'message.resend_failed',
        attrs: {'message.id': messageId},
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }
}
