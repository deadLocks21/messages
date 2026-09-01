import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Pose — ou retire — une réaction sur un message.
///
/// ## C'est un SMS, et il est facturé
///
/// Il n'y a pas d'autre canal : Android n'ouvre pas le RCS aux applications
/// tierces, et une réaction part donc comme un message ordinaire, dont le corps
/// imite ce qu'un iPhone envoie (`Liked “Bonjour”`). Deux conséquences que rien
/// ne rattrape :
///
/// - l'emoji fait basculer le SMS en UCS-2, donc **70 caractères par segment** :
///   citer un long message coûte deux ou trois SMS. On cite quand même
///   largement — une citation trop courte ne se retrouve pas à l'arrivée, et la
///   réaction s'affiche alors en toutes lettres chez le correspondant ;
/// - la réaction **existe dans le stock**, visible de toute autre application
///   SMS de l'appareil. C'est aussi ce qui la fait survivre au redémarrage sans
///   qu'on tienne de base locale.
///
/// Une réaction ne se rappelle pas : la retirer envoie un second message
/// (`Removed a heart from “Bonjour”`), et coûte donc un SMS de plus.
class ReactToMessageUseCase {
  final MessageRepository _messages;
  final LoggerApplicationService _logger;

  const ReactToMessageUseCase(
    this._messages, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  /// [emoji] est celui qu'on pose ; [remove] envoie le retrait du même.
  ///
  /// @return le message qui la transporte, en `sending` comme tout envoi.
  Future<MessageDto> execute({
    required String messageId,
    required List<String> recipients,
    required String emoji,
    bool remove = false,
  }) async {
    final addresses = recipients
        .map(Address.tryParse)
        .whereType<Address>()
        .toList();

    try {
      final target = await _messages.getById(messageId);
      if (target == null) throw const MessageNotFoundException();
      if (addresses.isEmpty) {
        throw const MessageSendFailedException('Aucun destinataire');
      }

      final quoted = ReactionCodec.targetOf(target);
      final body = remove
          ? ReactionCodec.encodeRemoval(emoji: emoji, target: quoted)
          : ReactionCodec.encode(emoji: emoji, target: quoted);

      final sent = await _messages.send(recipients: addresses, body: body);

      // Ce qui est journalisé dit le **coût** et le **format**, jamais le
      // contenu : savoir qu'une réaction est partie sous un verbe iOS plutôt
      // que sous la forme emoji est exactement ce qu'il faudra relire le jour
      // où un correspondant dit qu'il voit du texte à la place d'un emoji.
      await _logger.info(
        'message.reacted',
        attrs: {
          'reaction.removal': remove,
          'reaction.tapback': ReactionCodec.hasTapback(emoji),
          'reaction.quoted_attachment': ReactionCodec.isAttachmentLabel(quoted),
          'body.length': body.length,
          'recipients.count': addresses.length,
        },
      );

      return MessageDto.fromDomain(sent);
    } catch (e, stack) {
      await _logger.error(
        'message.react_failed',
        attrs: {
          'reaction.removal': remove,
          'reaction.tapback': ReactionCodec.hasTapback(emoji),
          'recipients.count': addresses.length,
        },
        error: e,
        stack: stack,
      );
      rethrow;
    }
  }
}
