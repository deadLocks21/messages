import 'package:messages/core/domain/model/address.dart';

/// Une réaction posée sur un message : un emoji, et qui l'a posé.
///
/// Sur SMS, une réaction n'est pas un champ d'un message — c'est **un message
/// à part entière**, dont le corps suit la convention des tapbacks iMessage
/// (`Liked “Bonjour”`). [carrierId] est l'identifiant de ce message porteur
/// dans le stock : la réaction n'a pas d'existence propre, et c'est lui qu'on
/// supprime si l'on veut la faire disparaître.
class Reaction {
  /// L'emoji tel qu'on l'affiche — celui de la table de [ReactionCodec], pas
  /// forcément celui que l'expéditeur a choisi : un `Loved` d'iPhone n'a jamais
  /// été un caractère.
  final String emoji;

  /// Qui réagit : l'interlocuteur pour une réaction reçue, nous pour une
  /// réaction envoyée.
  final Address author;
  final bool isMine;
  final DateTime at;

  /// Le message du stock qui transporte la réaction.
  final String carrierId;

  const Reaction({
    required this.emoji,
    required this.author,
    required this.isMine,
    required this.at,
    required this.carrierId,
  }) : assert(emoji != '', 'emoji cannot be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reaction &&
          runtimeType == other.runtimeType &&
          carrierId == other.carrierId;

  @override
  int get hashCode => carrierId.hashCode;
}
