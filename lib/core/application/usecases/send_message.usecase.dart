import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/services/draft.repository.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Envoie un SMS et nettoie le brouillon du fil.
///
/// Le message rendu est en `sending` : c'est la plateforme qui confirmera le
/// dépôt puis la remise via [SmsEventSource]. L'UI l'affiche donc tout de suite,
/// avec son état, sans attendre le réseau.
class SendMessageUseCase {
  final MessageRepository _messages;
  final DraftRepository _drafts;

  const SendMessageUseCase({
    required MessageRepository messages,
    required DraftRepository drafts,
  }) : _messages = messages,
       _drafts = drafts;

  Future<MessageDto> execute({
    required List<String> recipients,
    required String body,
    int? subscriptionId,
  }) async {
    final text = body.trim();
    if (text.isEmpty) {
      throw const MessageSendFailedException('Message vide');
    }
    final addresses = recipients
        .map(Address.tryParse)
        .whereType<Address>()
        .toList();
    if (addresses.isEmpty) {
      throw const MessageSendFailedException('Aucun destinataire');
    }

    final sent = await _messages.send(
      recipients: addresses,
      body: text,
      subscriptionId: subscriptionId,
    );

    // Le brouillon a rempli son office : le garder ferait réapparaître le texte
    // au retour dans le fil.
    await _drafts.remove(sent.threadId);

    return MessageDto.fromDomain(sent);
  }
}
