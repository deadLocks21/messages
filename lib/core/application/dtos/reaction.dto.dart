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
