import 'package:messages/core/domain/model/emoji.dart';
import 'package:messages/core/domain/model/emoji_table.dart';

/// L'accès à la table des emoji, et la recherche qui va avec.
///
/// La table elle-même est **générée** (`emoji_table.dart`) depuis Unicode et
/// CLDR — voir `tool/generate_emoji_table.dart`. Elle vit dans le domaine et
/// non derrière un port : elle ne dépend d'aucune plateforme, ne varie pas
/// d'un appareil à l'autre et ne se lit nulle part. Un port n'aurait rien à
/// adapter.
///
/// Ce qui est **écarté** de la table, et pourquoi :
///
/// - les **teintes de peau** (👍🏽) : elles multiplieraient la table par six
///   pour la même grille. Les claviers montrent la base et laissent l'appui
///   long faire le reste — ce sera une fonctionnalité, pas une ligne de table ;
/// - les **modificateurs seuls** (le groupe « Component » d'Unicode), qui ne
///   s'affichent pas isolément.
abstract final class EmojiCatalog {
  /// Ce que porte chaque famille, dans l'ordre d'Unicode — celui de tous les
  /// claviers.
  static const groups = emojiTable;

  /// Toutes les familles, à plat.
  static final List<Emoji> all = List.unmodifiable(
    groups.values.expand((emojis) => emojis),
  );

  /// Les emoji dont le nom **ou l'un des mots-clés** contient [query].
  ///
  /// Les mots-clés sont ce qui fait la différence entre une recherche qui
  /// trouve et une recherche qui demande de deviner l'intitulé exact : « mdr »
  /// ne ressemble à aucun nom d'emoji, et pourtant c'est ce qu'on tape.
  ///
  /// La comparaison ignore la casse **et les accents** : « ecoeure » doit
  /// trouver « écœuré », sinon la recherche ne sert qu'à ceux qui savent déjà
  /// comment la table a orthographié ce qu'ils cherchent.
  ///
  /// Le classement met devant ce qui **commence** par le terme : « chat »
  /// doit rendre le chat avant le chapeau de paille, dont un mot-clé le
  /// contient.
  static List<Emoji> search(String query) {
    final needle = _fold(query);
    if (needle.isEmpty) return const [];

    final leading = <Emoji>[];
    final rest = <Emoji>[];
    for (final emoji in all) {
      final name = _folded(emoji.name);
      if (name.startsWith(needle)) {
        leading.add(emoji);
      } else if (name.contains(needle) ||
          emoji.keywords.any((k) => _folded(k).contains(needle))) {
        rest.add(emoji);
      }
    }
    return List.unmodifiable([...leading, ...rest]);
  }

  /// Retrouve un emoji par son caractère — ce que les récents ont retenu.
  static Emoji? byCharacter(String character) =>
      _byCharacter[character];

  static final Map<String, Emoji> _byCharacter = {
    for (final emoji in all) emoji.character: emoji,
  };

  /// Les formes repliées, calculées une fois.
  ///
  /// Une recherche parcourt deux mille emoji et une quinzaine de mots-clés
  /// chacun : replier à chaque frappe reviendrait à normaliser trente mille
  /// chaînes par lettre tapée.
  static final Map<String, String> _cache = {};

  static String _folded(String value) => _cache[value] ??= _fold(value);

  /// Minuscules, sans accent ni ligature, pour comparer deux mots écrits par
  /// deux personnes différentes.
  static String _fold(String value) {
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().trim().runes) {
      buffer.write(_foldedRunes[rune] ?? String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  static const _foldedRunes = <int, String>{
    0xE0: 'a', 0xE2: 'a', 0xE4: 'a', 0xE7: 'c', 0xE8: 'e', 0xE9: 'e',
    0xEA: 'e', 0xEB: 'e', 0xEE: 'i', 0xEF: 'i', 0xF4: 'o', 0xF6: 'o',
    0xF9: 'u', 0xFB: 'u', 0xFC: 'u', 0x153: 'oe', 0xE6: 'ae',
    // L'apostrophe typographique de CLDR (« il y a quelqu’un ? ») : personne
    // ne la tape.
    0x2019: "'",
  };
}
