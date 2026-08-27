import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Supprime un message du stock. Irréversible — Android ne tient pas de
/// corbeille.
class DeleteMessageUseCase {
  final MessageRepository _messages;
  final LoggerApplicationService _logger;

  const DeleteMessageUseCase(
    this._messages, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  Future<void> execute(String messageId) async {
    try {
      await _messages.delete(messageId);
      await _logger.info('message.deleted', attrs: {'message.id': messageId});
    } catch (e, stack) {
      // Sans le rôle d'app par défaut, le provider refuse l'écriture : la
      // bulle reste à l'écran et l'utilisateur croit à un bug d'affichage.
      await _logger.error(
        'message.delete_failed',
        attrs: {'message.id': messageId},
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }
}
