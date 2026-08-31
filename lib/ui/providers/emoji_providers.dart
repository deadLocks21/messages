import 'package:messages/core/application/dtos/emoji.dto.dart';
import 'package:messages/core/domain/model/emoji.dart';
import 'package:messages/core/domain/model/emoji_catalog.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'emoji_providers.g.dart';

/// Les sections de la grille : les récents, puis les familles.
///
/// Seuls les récents sont lus quelque part — le reste est une constante du
/// domaine. C'est pourquoi il n'y a qu'un `Future` ici, et qu'il ne porte que
/// sur la première section.
@riverpod
class EmojiSections extends _$EmojiSections {
  @override
  Future<List<EmojiSectionDto>> build() async {
    final characters = await ref
        .watch(emojiHistoryRepositoryProvider)
        .recents();

    return [
      EmojiSectionDto.fromDomain(
        EmojiSection(
          group: EmojiGroup.recents,
          // Un caractère retenu que la table ne connaît plus (elle a pu
          // changer d'une version à l'autre) reste utilisable : il n'a plus de
          // nom, il garde son glyphe.
          emojis: characters
              .map((c) => EmojiCatalog.byCharacter(c) ?? Emoji(c, c))
              .toList(),
        ),
      ),
      for (final entry in EmojiCatalog.groups.entries)
        EmojiSectionDto.fromDomain(
          EmojiSection(group: entry.key, emojis: entry.value),
        ),
    ];
  }

  /// Retient un emoji qu'on vient d'insérer, et remonte la section des
  /// récents.
  Future<void> remember(String character) async {
    await ref.read(emojiHistoryRepositoryProvider).remember(character);
    ref.invalidateSelf();
  }
}

/// Les emoji dont le nom contient [query]. Une recherche vide ne rend rien —
/// c'est l'appelant qui retombe alors sur les sections.
@riverpod
List<EmojiDto> emojiSearch(Ref ref, String query) => EmojiCatalog.search(query)
    .map(EmojiDto.fromDomain)
    .toList(growable: false);
