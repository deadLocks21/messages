import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/domain/model/emoji.dart';
import 'package:messages/core/domain/model/emoji_catalog.dart';
import 'package:messages/infrastructure/preferences/in_memory.emoji_history.repository.dart';
import 'package:messages/core/domain/services/emoji_history.repository.dart';

/// La table des emoji, et ce qui la rend utilisable : la recherche.
void main() {
  group('La table', () {
    test('couvre toutes les familles de la barre du bas', () {
      // Une famille sans emoji ferait une pastille qui ne mène nulle part.
      for (final group in EmojiGroup.values) {
        if (group == EmojiGroup.recents) continue;
        expect(EmojiCatalog.groups[group], isNotNull, reason: group.name);
        expect(EmojiCatalog.groups[group], isNotEmpty, reason: group.name);
      }
    });

    test('ne répète aucun caractère', () {
      final all = EmojiCatalog.all.map((e) => e.character).toList();
      // Un doublon ferait deux cellules identiques, et deux clés identiques
      // dans la grille.
      expect(all.toSet().length, all.length);
    });

    test('nomme chaque emoji', () {
      // Un emoji sans nom n'est atteignable qu'en défilant, ce qui, passé la
      // deuxième famille, revient à ne pas être atteignable.
      expect(EmojiCatalog.all.every((e) => e.name.trim().isNotEmpty), isTrue);
    });

    test('porte la table entière d\'Unicode, pas un échantillon', () {
      // La première version en comptait cinq cents, choisis à vue — et il en
      // manquait forcément.
      expect(EmojiCatalog.all.length, greaterThan(1800));
    });

    test('écarte les teintes de peau et garde les bases', () {
      // Elles multiplieraient la table par six pour la même grille : les
      // claviers montrent la base et laissent l'appui long faire le reste.
      final withTone = EmojiCatalog.all.where(
        (e) => e.character.runes.any((r) => r >= 0x1F3FB && r <= 0x1F3FF),
      );
      expect(withTone, isEmpty);
      expect(EmojiCatalog.byCharacter('👍'), isNotNull);
    });

    test('couvre ce qu\'un clavier montre et que cinq cents entrées rataient', () {
      for (final character in ['🫠', '🫡', '🩷', '👨‍⚕️', '🇧🇪', '🧑‍🚒', '🪿']) {
        expect(
          EmojiCatalog.byCharacter(character),
          isNotNull,
          reason: character,
        );
      }
    });
  });

  group('La recherche', () {
    test('trouve par un morceau de nom', () {
      expect(
        EmojiCatalog.search('licorne').map((e) => e.character),
        contains('🦄'),
      );
    });

    test('ignore les accents dans les deux sens', () {
      // « ecoeure » doit trouver « écœuré » : sinon la recherche ne sert qu'à
      // ceux qui savent déjà comment l'app a orthographié ce qu'ils cherchent.
      expect(EmojiCatalog.search('ecoeure').map((e) => e.character),
          contains('🤢'));
      expect(EmojiCatalog.search('cœur').map((e) => e.character),
          contains('❤️'));
      expect(EmojiCatalog.search('coeur').map((e) => e.character),
          contains('❤️'));
    });

    test('ignore la casse et les espaces autour', () {
      expect(EmojiCatalog.search('  PIZZA ').map((e) => e.character),
          contains('🍕'));
    });

    test('trouve par un mot-clé, pas seulement par le nom', () {
      // « mdr » ne ressemble à aucun nom d'emoji, et pourtant c'est ce qu'on
      // tape.
      expect(EmojiCatalog.search('mdr'), isNotEmpty);
      // « automobile » n'est le nom d'aucun emoji ; c'est un mot-clé de CLDR
      // sur la voiture.
      expect(
        EmojiCatalog.search('automobile').map((e) => e.character),
        contains('🚗'),
      );
    });

    test('met devant ce qui commence par le terme', () {
      // « chat » doit rendre le chat avant le chapeau, dont un mot-clé le
      // contient.
      final results = EmojiCatalog.search('chat');
      expect(results.first.name, startsWith('chat'));
    });

    test('ne rend rien pour une recherche vide', () {
      // C'est à l'appelant de retomber alors sur les sections : rendre tout
      // ferait défiler trois cents emoji sans titre ni famille.
      expect(EmojiCatalog.search('   '), isEmpty);
    });

    test('retrouve un emoji par son caractère', () {
      expect(EmojiCatalog.byCharacter('🍕')?.name, 'pizza');
      expect(EmojiCatalog.byCharacter('🛸🛸'), isNull);
    });
  });

  group('Les récents', () {
    test('remontent en tête sans se dédoubler', () async {
      final history = InMemoryEmojiHistoryRepository();

      await history.remember('😀');
      await history.remember('🍕');
      await history.remember('😀');

      expect(await history.recents(), ['😀', '🍕']);
    });

    test('s\'arrêtent à deux rangées', () async {
      final history = InMemoryEmojiHistoryRepository();
      for (final emoji in EmojiCatalog.all.take(30)) {
        await history.remember(emoji.character);
      }

      expect(
        (await history.recents()).length,
        EmojiHistoryRepository.maxCount,
      );
    });
  });
}
