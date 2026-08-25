import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';

/// Résout le fil correspondant à une liste de destinataires, en le créant si
/// besoin. C'est ce qui permet d'ouvrir une conversation depuis le sélecteur de
/// contacts avant même le premier message : le fil existe, il est simplement
/// vide.
class StartConversationUseCase {
  final ConversationRepository _conversations;

  const StartConversationUseCase(this._conversations);

  Future<String> execute(List<String> recipients) async {
    final addresses = recipients
        .map(Address.tryParse)
        .whereType<Address>()
        .toList();
    if (addresses.isEmpty) {
      throw const MessageSendFailedException('Aucun destinataire');
    }
    return _conversations.resolveThreadId(addresses);
  }
}
