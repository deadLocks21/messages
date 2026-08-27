import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/draft.repository.dart';
import 'package:messages/core/domain/services/message.repository.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';

/// Envoie un message — SMS, ou MMS dès qu'il porte des pièces jointes — et
/// nettoie le brouillon du fil.
///
/// Les messages rendus sont en `sending` : c'est la plateforme qui confirmera
/// le dépôt puis la remise via [SmsEventSource]. L'UI les affiche donc tout de
/// suite, avec leur état, sans attendre le réseau.
///
/// ## Une pièce jointe par message
///
/// Plusieurs pièces jointes partent en **plusieurs MMS**, un par pièce. Le
/// budget d'un MMS étant fixe, les regrouper le partagerait : trois photos
/// dans un message n'auraient qu'un tiers de la qualité chacune. Séparées,
/// chacune dispose du budget entier.
///
/// Le prix de ce choix est explicite : le MMS est souvent facturé à l'unité,
/// et trois photos coûtent donc trois messages. C'est un arbitrage assumé en
/// faveur de la qualité.
///
/// La légende accompagne le **premier** message. La répéter sur chacun
/// donnerait au destinataire l'impression d'un bégaiement.
class SendMessageUseCase {
  final MessageRepository _messages;
  final DraftRepository _drafts;
  final MmsConfiguration _configuration;
  final LoggerApplicationService _logger;

  const SendMessageUseCase({
    required MessageRepository messages,
    required DraftRepository drafts,
    required MmsConfiguration configuration,
    required LoggerApplicationService logger,
  }) : _messages = messages,
       _drafts = drafts,
       _configuration = configuration,
       _logger = logger;

  /// @return un message par envoi réellement déposé, dans l'ordre.
  ///
  /// L'envoi est le geste que l'app doit réussir : chaque tentative laisse une
  /// trace (`message.send` / `message.send_failed`) portant de quoi la relire
  /// sans l'appareil sous la main — transport choisi, nombre de destinataires,
  /// poids des pièces jointes. Le **contenu** n'y figure jamais : ni le texte,
  /// ni les numéros. Un log de production se lit par d'autres yeux que ceux du
  /// destinataire.
  Future<List<MessageDto>> execute({
    required List<String> recipients,
    required String body,
    List<AttachmentDraft> attachments = const [],
    int? subscriptionId,
  }) async {
    try {
      return await _execute(
        recipients: recipients,
        body: body,
        attachments: attachments,
        subscriptionId: subscriptionId,
      );
    } catch (e, stack) {
      await _logger.error(
        'message.send_failed',
        attrs: {
          'recipients.count': recipients.length,
          'body.length': body.trim().length,
          'attachments.count': attachments.length,
        },
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }

  Future<List<MessageDto>> _execute({
    required List<String> recipients,
    required String body,
    required List<AttachmentDraft> attachments,
    int? subscriptionId,
  }) async {
    final text = body.trim();
    // Une photo seule est un message parfaitement valide : c'est le couple
    // (texte, pièces jointes) qui doit être non vide, pas le texte.
    if (text.isEmpty && attachments.isEmpty) {
      throw const MessageSendFailedException('Message vide');
    }
    if (attachments.length > MmsLimits.maxCount) {
      throw const TooManyAttachmentsException();
    }
    if (attachments.isNotEmpty) {
      // Dernier filet : le plateau a normalement déjà été ajusté au budget,
      // mais rien n'oblige un appelant à passer par là. Chaque pièce partant
      // seule, c'est chacune — et non leur somme — qui doit tenir.
      final limits = await _configuration.limits();
      final tropLourde = attachments.any(
        (a) => a.byteSize > limits.contentBytes,
      );
      if (tropLourde) throw AttachmentTooLargeException(limits);
    }
    final addresses = recipients
        .map(Address.tryParse)
        .whereType<Address>()
        .toList();
    if (addresses.isEmpty) {
      throw const MessageSendFailedException('Aucun destinataire');
    }

    // Sans pièce jointe, il n'y a rien à découper.
    if (attachments.isEmpty) {
      return [
        await _sendOne(
          addresses: addresses,
          body: text,
          attachments: const [],
          subscriptionId: subscriptionId,
        ),
      ];
    }

    final sent = <MessageDto>[];
    for (final attachment in attachments) {
      // Séquentiel, et non en parallèle : c'est ce qui garde les messages dans
      // l'ordre où l'utilisateur a posé ses pièces jointes. Une erreur
      // interrompt la suite, en laissant partis ceux qui l'étaient déjà — leur
      // bulle porte son propre état, le fil dit donc la vérité.
      sent.add(
        await _sendOne(
          addresses: addresses,
          // La légende va au premier, une seule fois.
          body: sent.isEmpty ? text : '',
          attachments: [attachment],
          subscriptionId: subscriptionId,
        ),
      );
    }
    return sent;
  }

  Future<MessageDto> _sendOne({
    required List<Address> addresses,
    required String body,
    required List<AttachmentDraft> attachments,
    int? subscriptionId,
  }) async {
    final sent = await _messages.send(
      recipients: addresses,
      body: body,
      attachments: attachments,
      subscriptionId: subscriptionId,
    );

    // Le transport n'est pas choisi par l'appelant mais déduit de la présence
    // de pièces jointes : le tracer évite d'avoir à re-dérouler ce
    // raisonnement en lisant les logs.
    await _logger.info(
      'message.send',
      attrs: {
        'message.transport': attachments.isEmpty ? 'sms' : 'mms',
        'message.id': sent.id,
        'thread.id': sent.threadId,
        'recipients.count': addresses.length,
        'body.length': body.length,
        'attachments.count': attachments.length,
        if (attachments.isNotEmpty)
          'attachments.bytes': attachments.fold<int>(
            0,
            (sum, a) => sum + a.byteSize,
          ),
        if (attachments.isNotEmpty) 'attachment.mime': attachments.first.mimeType,
      },
    );

    // Le brouillon a rempli son office : le garder ferait réapparaître le texte
    // au retour dans le fil.
    await _drafts.remove(sent.threadId);

    return MessageDto.fromDomain(sent);
  }
}
