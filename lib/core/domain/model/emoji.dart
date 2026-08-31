/// Un emoji, et le nom sous lequel on le cherche.
///
/// Le nom n'est pas décoratif : c'est **la seule prise** qu'on ait sur un
/// caractère qu'on ne sait pas taper. C'est lui que le champ de recherche
/// interroge, et lui qu'un lecteur d'écran annonce à la place d'un glyphe
/// qu'il ne saurait pas dire.
class Emoji {
  /// Le caractère lui-même. Souvent plusieurs points de code — une séquence à
  /// jonction (`👨‍👩‍👧`) en compte huit.
  final String character;

  /// Nom court, en français, sans article — celui de CLDR.
  final String name;

  /// Les autres mots par lesquels on peut le chercher (« bagnole » pour une
  /// voiture, « lol » pour un fou rire).
  ///
  /// Ils viennent de CLDR, comme le nom, et c'est ce qui fait la différence
  /// entre une recherche qui trouve et une recherche qui demande de deviner
  /// l'intitulé exact. Vide pour les rares emoji que CLDR ne décrit pas encore
  /// en français.
  final List<String> keywords;

  const Emoji(this.character, this.name, {this.keywords = const []})
    : assert(character != '', 'character cannot be empty'),
      assert(name != '', 'name cannot be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Emoji &&
          runtimeType == other.runtimeType &&
          character == other.character;

  @override
  int get hashCode => character.hashCode;
}

/// Les familles de la barre du bas, dans l'ordre où l'app d'origine les range.
///
/// [recents] n'est pas une famille d'Unicode mais une famille d'usage : elle
/// vient en tête parce que c'est là que se trouve, neuf fois sur dix, l'emoji
/// qu'on cherche.
enum EmojiGroup {
  recents('Récents'),
  smileys('Émoticônes et émotions'),
  people('Personnes'),
  animals('Animaux et nature'),
  food('Nourriture et boissons'),
  travel('Voyages et lieux'),
  activities('Activités et événements'),
  objects('Objets'),
  symbols('Symboles'),
  flags('Drapeaux');

  /// Ce qu'affiche l'en-tête de section, mis en capitales par l'UI — comme le
  /// fait l'app d'origine (« ÉMOTICÔNES ET ÉMOTIONS »).
  final String label;

  const EmojiGroup(this.label);
}

/// Une section de la grille : son titre et ce qu'elle contient.
///
/// Une section **vide se montre quand même** quand c'est [EmojiGroup.recents] :
/// l'app d'origine y écrit « Vous n'avez encore utilisé aucun emoji », et c'est
/// ce qui explique pourquoi la première fois ne ressemble pas aux suivantes.
class EmojiSection {
  final EmojiGroup group;
  final List<Emoji> emojis;

  EmojiSection({required this.group, required List<Emoji> emojis})
    : emojis = List.unmodifiable(emojis);

  bool get isEmpty => emojis.isEmpty;
}
