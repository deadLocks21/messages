import 'package:messages/core/domain/services/message.repository.dart';

/// Supprime un message du stock. Irréversible — Android ne tient pas de
/// corbeille.
class DeleteMessageUseCase {
  final MessageRepository _messages;

  const DeleteMessageUseCase(this._messages);

  Future<void> execute(String messageId) => _messages.delete(messageId);
}
