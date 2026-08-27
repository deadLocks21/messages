import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';

/// Résout le fil correspondant à une liste de destinataires, en le créant si
/// besoin. C'est ce qui permet d'ouvrir une conversation depuis le sélecteur de
/// contacts avant même le premier message : le fil existe, il est simplement
/// vide.
class StartConversationUseCase {
  final ConversationRepository _conversations;
  final LoggerApplicationService _logger;

  const StartConversationUseCase(
    this._conversations, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  Future<String> execute(List<String> recipients) async {
    final addresses = recipients
        .map(Address.tryParse)
        .whereType<Address>()
        .toList();
    if (addresses.isEmpty) {
      // Un numéro que `Address` refuse est le début d'un fil qui n'ouvrira
      // jamais : c'est le genre d'échec qu'on ne reproduit pas sans savoir
      // combien de fois il arrive.
      await _logger.warn(
        'conversation.start_failed',
        attrs: {
          'reason': 'no_valid_recipient',
          'recipients.count': recipients.length,
        },
      );
      throw const MessageSendFailedException('Aucun destinataire');
    }
    try {
      return await _conversations.resolveThreadId(addresses);
    } catch (e, stack) {
      await _logger.error(
        'conversation.start_failed',
        attrs: {
          'reason': 'resolve_failed',
          'recipients.count': addresses.length,
        },
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }
}
