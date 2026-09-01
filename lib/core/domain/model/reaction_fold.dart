import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/model/reaction.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';

/// Un fil dont les réactions ont été retirées des bulles et posées sur celles
/// qu'elles visent.
class FoldedThread {
  /// Les messages qui restent des bulles.
  final List<Message> messages;

  /// Réactions par identifiant de message visé.
  final Map<String, List<Reaction>> reactions;

  const FoldedThread({required this.messages, required this.reactions});

  List<Reaction> on(String messageId) => reactions[messageId] ?? const [];
}

/// Le repli des réactions dans le fil.
///
/// Sur SMS, une réaction est un message comme un autre : elle est dans le stock,
/// elle a un identifiant, elle coûte un SMS. Ce que l'app en fait n'est donc pas
/// un stockage — c'est une **règle de présentation**, et c'est pour cela qu'elle
/// vit ici et pas dans une base locale que le projet n'a pas.
///
/// Deux garde-fous gouvernent tout le reste :
///
/// - **Pas de cible, pas de repli.** Un message dont on ne retrouve pas la
///   citation reste la bulle de texte qu'il est. C'est ce qui empêche un
///   « 👍 to be honest » d'avaler une conversation, et c'est ce qui garantit
///   qu'aucun message n'est masqué sans raison lisible.
/// - **Un échec reste visible.** Une réaction qu'on n'a pas réussi à envoyer
///   garde sa bulle et son bouton « Réessayer » : repliée, elle disparaîtrait
///   avec son échec, et l'utilisateur croirait avoir réagi.
abstract final class ReactionFolder {
  /// [enabled] à `false` rend le fil tel quel : c'est le réglage « afficher
  /// les réactions comme des emoji » sur `off`, et c'est aussi ce qui permet
  /// de voir ce qui circule réellement quand un correspondant se plaint.
  static FoldedThread fold(List<Message> messages, {bool enabled = true}) {
    if (!enabled) {
      return FoldedThread(messages: messages, reactions: const {});
    }

    final bubbles = <Message>[];
    final reactions = <String, List<Reaction>>{};

    for (final message in messages) {
      final decoded = ReactionCodec.decode(message.body);
      // Un échec garde sa bulle : c'est la seule trace de ce qui n'est pas
      // parti.
      if (decoded == null || message.status == MessageStatus.failed) {
        bubbles.add(message);
        continue;
      }

      final target = _targetOf(decoded, message, bubbles);
      if (target == null) {
        bubbles.add(message);
        continue;
      }

      final posted = reactions.putIfAbsent(target.id, () => []);
      final author = _authorKeyOf(message);
      // Une réaction remplace la précédente du même auteur : sur un tapback,
      // on ne cumule pas, on change d'avis.
      posted.removeWhere((r) => _authorKey(r) == author);
      if (decoded.isRemoval) continue;

      posted.add(
        Reaction(
          emoji: decoded.emoji,
          author: message.address,
          isMine: message.isOutgoing,
          at: message.sentAt,
          carrierId: message.id,
        ),
      );
    }

    reactions.removeWhere((_, posted) => posted.isEmpty);
    return FoldedThread(messages: bubbles, reactions: reactions);
  }

  /// Le message visé par cette réaction, cherché du plus récent au plus ancien
  /// parmi les bulles qui la précèdent.
  ///
  /// Le plus récent gagne : dans un fil où « Bonjour » a été dit trois fois,
  /// c'est au dernier qu'on vient de réagir. On ne filtre pas sur le sens —
  /// dans un groupe, on réagit aussi bien au message d'un tiers qu'au sien.
  static Message? _targetOf(
    ReactionText decoded,
    Message carrier,
    List<Message> earlier,
  ) {
    final label = !decoded.wasQuoted &&
        ReactionCodec.isAttachmentLabel(decoded.quoted);

    for (final candidate in earlier.reversed) {
      if (candidate.id == carrier.id) continue;
      if (label) {
        // Une pièce jointe n'a pas de texte à citer : iOS la nomme par sa
        // nature (« an image »). Le rattachement se fait alors sur la dernière
        // pièce jointe du fil — c'est approximatif, mais c'est cela ou
        // renoncer à réagir aux photos.
        if (candidate.attachments.isNotEmpty) return candidate;
        continue;
      }
      if (candidate.body.trim().isEmpty) continue;
      if (ReactionCodec.matches(
        decoded.quoted,
        candidate.body,
        // Une citation entre guillemets peut avoir été coupée : elle vaut pour
        // préfixe. Sans guillemets, il faut le message entier, sinon le
        // moindre début de phrase commun ferait cible.
        asPrefix: decoded.wasQuoted,
      )) {
        return candidate;
      }
    }
    return null;
  }

  static String _authorKeyOf(Message message) =>
      message.isOutgoing ? '' : message.address.key;

  static String _authorKey(Reaction reaction) =>
      reaction.isMine ? '' : reaction.author.key;
}
