import 'package:messages/core/domain/model/emoji.dart';

/// Un emoji prêt pour la grille : le caractère, et de quoi l'annoncer.
class EmojiDto {
  final String character;
  final String name;

  const EmojiDto({required this.character, required this.name});

  factory EmojiDto.fromDomain(Emoji emoji) =>
      EmojiDto(character: emoji.character, name: emoji.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmojiDto &&
          runtimeType == other.runtimeType &&
          character == other.character;

  @override
  int get hashCode => character.hashCode;
}

/// Une section de la grille — un titre, et ce qu'il y a dessous.
///
/// [isRecents] parce que c'est la seule section qui se montre **vide** :
/// l'app d'origine y écrit qu'aucun emoji n'a encore servi, là où une famille
/// vide n'aurait rien à dire.
class EmojiSectionDto {
  final String title;
  final List<EmojiDto> emojis;
  final bool isRecents;

  const EmojiSectionDto({
    required this.title,
    required this.emojis,
    this.isRecents = false,
  });

  factory EmojiSectionDto.fromDomain(EmojiSection section) => EmojiSectionDto(
    title: section.group.label,
    emojis: section.emojis.map(EmojiDto.fromDomain).toList(growable: false),
    isRecents: section.group == EmojiGroup.recents,
  );
}
