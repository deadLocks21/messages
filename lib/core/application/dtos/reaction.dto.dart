import 'package:messages/core/application/dtos/avatar.dto.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/reaction.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';

/// Une pastille de réaction sous une bulle : un emoji, et combien de personnes
/// l'ont posé.
class ReactionDto {
  final String emoji;
  final int count;

  /// L'utilisateur fait partie de ceux qui ont posé cet emoji — la pastille se
  /// souligne, et un nouvel appui sur le même emoji le retire.
  final bool isMine;

  const ReactionDto({
    required this.emoji,
    required this.count,
    required this.isMine,
  });

  /// Ce qu'un lecteur d'écran annonce d'une pastille.
  String get label {
    final what = ReactionCodec.describe(emoji);
    if (count > 1) return 'Réaction $what, $count personnes';
    return isMine ? 'Votre réaction $what' : 'Réaction $what';
  }

  /// Regroupe les réactions d'un message par emoji, dans l'ordre où elles sont
  /// arrivées — la première posée reste la première affichée, comme partout
  /// ailleurs.
  static List<ReactionDto> group(List<Reaction> reactions) {
    final order = <String>[];
    final counts = <String, int>{};
    final mine = <String>{};

    for (final reaction in reactions) {
      final emoji = ReactionCodec.canonical(reaction.emoji);
      if (!counts.containsKey(emoji)) order.add(emoji);
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (reaction.isMine) mine.add(emoji);
    }

    return [
      for (final emoji in order)
        ReactionDto(
          emoji: emoji,
          count: counts[emoji]!,
          isMine: mine.contains(emoji),
        ),
    ];
  }
}

/// Une réaction **vue par son auteur** : qui a posé quoi.
///
/// C'est le pendant de [ReactionDto], qui regroupe par emoji pour la pastille.
/// Ici on ne regroupe pas — la fiche « Réactions » de l'app d'origine liste des
/// **personnes**, une ligne chacune, parce que la question qu'on lui pose n'est
/// pas « combien de pouces » mais « qui a mis le pouce ».
class ReactionAuthorDto {
  final String emoji;

  /// Nom du carnet d'adresses, le numéro formaté à défaut — et « Vous » pour
  /// la sienne, comme l'app d'origine qui écrit « You » plutôt que de répéter
  /// le nom du propriétaire du téléphone.
  final String name;

  /// Pastille du réacteur — `null` pour la sienne : l'auteur d'une réaction
  /// sortante est l'adresse du fil, c'est-à-dire le correspondant. Peindre son
  /// avatar sur la ligne « Vous » y afficherait le visage de l'autre. L'UI met
  /// à la place la pastille de compte, celle de la barre du haut.
  final AvatarDto? avatar;

  final bool isMine;

  const ReactionAuthorDto({
    required this.emoji,
    required this.name,
    required this.avatar,
    required this.isMine,
  });

  /// Ce qu'un lecteur d'écran annonce d'une ligne.
  String get label => '$name, ${ReactionCodec.describe(emoji)}';

  /// Une ligne par réaction, dans l'ordre où elles sont arrivées — le même que
  /// celui des pastilles, pour qu'on retrouve dans la fiche l'ordre qu'on
  /// vient de lire sur la bulle.
  static List<ReactionAuthorDto> list(
    List<Reaction> reactions, {
    required String Function(Address) nameFor,
    required AvatarDto Function(Address) avatarFor,
  }) {
    return [
      for (final reaction in reactions)
        ReactionAuthorDto(
          emoji: ReactionCodec.canonical(reaction.emoji),
          name: reaction.isMine ? 'Vous' : nameFor(reaction.author),
          avatar: reaction.isMine ? null : avatarFor(reaction.author),
          isMine: reaction.isMine,
        ),
    ];
  }
}
