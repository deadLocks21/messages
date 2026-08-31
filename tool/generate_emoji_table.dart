// Génère `lib/core/domain/model/emoji_table.dart` depuis les données Unicode
// et CLDR.
//
//     dart run tool/generate_emoji_table.dart
//
// Pourquoi un générateur et pas une table écrite à la main : la première
// version de cette table en comptait cinq cents, choisis à vue — et il en
// manquait forcément, puisque « les emoji habituels » de quelqu'un ne sont
// jamais tout à fait ceux d'un autre. Unicode publie la liste **ordonnée et
// groupée** (`emoji-test.txt`), CLDR publie les **noms et mots-clés
// français** : les deux ensemble donnent la table entière, dans l'ordre où
// tous les claviers du monde la présentent, et avec de quoi la chercher.
//
// Le fichier produit est **committé** : l'app ne télécharge rien: on relance
// ce script quand une version d'Unicode sort.
//
// Données sous licence Unicode (https://www.unicode.org/license.txt).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Version d'Unicode visée. Épinglée plutôt que « latest » : une table qui
/// change sous les pieds au prochain lancement rendrait le diff illisible.
const emojiVersion = '16.0';

const emojiTestUrl =
    'https://unicode.org/Public/emoji/$emojiVersion/emoji-test.txt';
const cldrBase =
    'https://raw.githubusercontent.com/unicode-org/cldr/main/common';

/// Les familles d'Unicode, dans l'ordre, et le nom qu'elles portent chez nous.
/// « Component » n'en est pas une : ce sont les modificateurs (teintes de
/// peau, jonctions), qui ne s'affichent pas seuls.
const groups = <String, String>{
  'Smileys & Emotion': 'smileys',
  'People & Body': 'people',
  'Animals & Nature': 'animals',
  'Food & Drink': 'food',
  'Travel & Places': 'travel',
  'Activities': 'activities',
  'Objects': 'objects',
  'Symbols': 'symbols',
  'Flags': 'flags',
};

Future<void> main() async {
  final test = await _get(emojiTestUrl);
  final annotations = <String, _Annotation>{};
  // Les deux fichiers sont disjoints : `annotations` porte les caractères
  // simples, `annotationsDerived` les séquences (drapeaux, familles, métiers).
  for (final path in ['annotations/fr.xml', 'annotationsDerived/fr.xml']) {
    _parseAnnotations(await _get('$cldrBase/$path'), annotations);
  }

  final byGroup = <String, List<_Entry>>{for (final g in groups.values) g: []};
  var group = '';
  var skipped = 0;

  for (final line in const LineSplitter().convert(test)) {
    final header = RegExp(r'^# group: (.+)$').firstMatch(line);
    if (header != null) {
      group = groups[header.group(1)!.trim()] ?? '';
      continue;
    }
    if (group.isEmpty || line.startsWith('#') || line.trim().isEmpty) continue;

    // `1F600 ; fully-qualified # 😀 E1.0 grinning face`
    final match = RegExp(
      r'^([0-9A-F ]+);\s*fully-qualified\s*#\s(\S+)\sE[\d.]+\s(.+)$',
    ).firstMatch(line);
    if (match == null) continue;

    final codes = match
        .group(1)!
        .trim()
        .split(' ')
        .map((c) => int.parse(c, radix: 16));
    // Les teintes de peau multiplieraient la table par six pour la même
    // grille : les claviers montrent la base et laissent l'appui long faire le
    // reste. Ce sera une fonctionnalité, pas une ligne de table.
    if (codes.any((c) => c >= 0x1F3FB && c <= 0x1F3FF)) {
      skipped++;
      continue;
    }

    final character = match.group(2)!;
    final annotation = annotations[_annotationKey(character)];
    byGroup[group]!.add(
      _Entry(
        character: character,
        // Sans nom français — un emoji tout juste normalisé —, le nom anglais
        // vaut mieux que rien : il reste cherchable, et la grille le montre.
        name: annotation?.name ?? match.group(3)!.trim(),
        keywords: annotation?.keywords ?? const [],
      ),
    );
  }

  final buffer = StringBuffer()
    ..writeln('// GÉNÉRÉ — ne pas modifier à la main.')
    ..writeln('//')
    ..writeln('// Produit par `dart run tool/generate_emoji_table.dart`, à')
    ..writeln('// partir de :')
    ..writeln('//   - Unicode emoji $emojiVersion (`emoji-test.txt`) pour la')
    ..writeln('//     liste, l\'ordre et les familles ;')
    ..writeln('//   - CLDR (annotations `fr`) pour les noms et les mots-clés.')
    ..writeln('//')
    ..writeln('// Données sous licence Unicode :')
    ..writeln('// https://www.unicode.org/license.txt')
    ..writeln("import 'package:messages/core/domain/model/emoji.dart';")
    ..writeln()
    ..writeln('/// La table entière, par famille et dans l\'ordre d\'Unicode.')
    ..writeln('const emojiTable = <EmojiGroup, List<Emoji>>{');

  var total = 0;
  for (final entry in byGroup.entries) {
    buffer.writeln('  EmojiGroup.${entry.key}: <Emoji>[');
    for (final emoji in entry.value) {
      total++;
      buffer.writeln(
        "    Emoji('${emoji.character}', ${_dart(emoji.name)}"
        '${emoji.keywords.isEmpty ? '' : ', keywords: ${_dartList(emoji.keywords)}'}),',
      );
    }
    buffer.writeln('  ],');
  }
  buffer.writeln('};');

  final out = File('lib/core/domain/model/emoji_table.dart');
  await out.writeAsString(buffer.toString());

  stdout.writeln('$total emoji écrits dans ${out.path}');
  stdout.writeln('$skipped variantes de teinte écartées');
  for (final entry in byGroup.entries) {
    stdout.writeln('  ${entry.key.padRight(12)} ${entry.value.length}');
  }
}

Future<String> _get(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw StateError('$url → HTTP ${response.statusCode}');
  }
  return utf8.decode(response.bodyBytes);
}

void _parseAnnotations(String xml, Map<String, _Annotation> into) {
  final pattern = RegExp(
    r'<annotation cp="([^"]+)"(\s+type="tts")?>([^<]*)</annotation>',
  );
  for (final match in pattern.allMatches(xml)) {
    final cp = _annotationKey(_unescape(match.group(1)!));
    final isName = match.group(2) != null;
    final value = _unescape(match.group(3)!);
    final current = into[cp] ?? _Annotation();
    if (isName) {
      current.name = value.trim();
    } else {
      current.keywords = value
          .split('|')
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();
    }
    into[cp] = current;
  }
}

/// La clé sous laquelle CLDR range une annotation.
///
/// `emoji-test.txt` donne la forme **pleinement qualifiée** (avec les
/// sélecteurs de variante U+FE0F), CLDR la forme **minimale** sans eux :
/// `👨‍⚕️` d'un côté, `👨‍⚕` de l'autre. Sans ce rabotage, toutes les séquences
/// à jonction — les métiers, les familles, les cœurs de couleur — se
/// retrouveraient sans nom français.
String _annotationKey(String character) =>
    character.replaceAll('\uFE0F', '');

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

String _dart(String value) => "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String _dartList(List<String> values) =>
    '[${values.map(_dart).join(', ')}]';

class _Annotation {
  String? name;
  List<String>? keywords;
}

class _Entry {
  final String character;
  final String name;
  final List<String> keywords;

  _Entry({
    required this.character,
    required this.name,
    required this.keywords,
  });
}
