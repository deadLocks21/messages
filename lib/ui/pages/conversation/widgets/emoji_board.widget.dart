import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/emoji.dto.dart';
import 'package:messages/ui/pages/conversation/widgets/expression_picker.widget.dart';
import 'package:messages/ui/providers/emoji_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// L'onglet Emoji : la grille par familles, et la barre du bas.
///
/// Relevé sur l'émulateur (1080 × 2400, 420 dpi) :
///
/// | Élément | Relevé |
/// |---|---|
/// | Grille | **9 colonnes**, cellules de 44,2 × 48 dp, retrait de 6 dp, glyphe de 32 dp |
/// | En-tête de section | 26 dp, capitales, 12 sp |
/// | Barre du bas | 48 dp ; icônes de 20 dp dans des cases de 48 dp ; retour arrière **calé à droite** dans sa propre case |
/// | Famille active | disque de 34 dp en `accentSoft`, glyphe en `accent` |
///
/// Deux choses qui ne se lisent pas sur une capture :
///
/// - **La grille est virtualisée par rangées.** Cinq cents `Text` construits
///   d'un coup pour n'en montrer que soixante-dix coûteraient une demi-seconde
///   à chaque ouverture. Comme toutes les hauteurs sont connues d'avance (48 dp
///   par rangée, 26 par en-tête), la position de chaque famille se **calcule**
///   au lieu de se mesurer : c'est ce qui permet à la fois de sauter à une
///   famille d'un appui, et de savoir laquelle est à l'écran.
/// - **Les récents se montrent même vides.** C'est la seule section dans ce
///   cas : l'app d'origine y écrit qu'aucun emoji n'a encore servi, ce qui
///   explique pourquoi la première ouverture ne ressemble pas aux suivantes.
///   Une famille vide, elle, n'aurait rien à dire.
class EmojiBoard extends ConsumerStatefulWidget {
  const EmojiBoard({
    super.key,
    required this.controller,
    required this.query,
  });

  /// Le champ de rédaction : c'est **dedans** que le panneau écrit, au
  /// curseur, et c'est dedans que la touche de retour arrière efface.
  final TextEditingController controller;

  final String query;

  static const columns = 9;
  static const cellHeight = 48.0;
  static const glyphSize = 32.0;
  static const inset = 6.0;
  static const sectionHeaderHeight = 26.0;
  static const categoryBarHeight = 48.0;
  static const categoryIconSize = 20.0;
  static const categoryIndicatorSize = 34.0;

  @override
  ConsumerState<EmojiBoard> createState() => _EmojiBoardState();
}

/// Une ligne de la liste : un titre, une rangée d'emoji, ou le mot qui tient
/// lieu de récents.
sealed class _Line {
  const _Line();
  double get height;
}

class _TitleLine extends _Line {
  final String title;
  const _TitleLine(this.title);
  @override
  double get height => EmojiBoard.sectionHeaderHeight;
}

class _EmojiLine extends _Line {
  final List<EmojiDto> emojis;
  const _EmojiLine(this.emojis);
  @override
  double get height => EmojiBoard.cellHeight;
}

class _EmptyLine extends _Line {
  final String text;
  const _EmptyLine(this.text);
  @override
  double get height => EmojiBoard.cellHeight;
}

class _EmojiBoardState extends ConsumerState<EmojiBoard> {
  final ScrollController _scroll = ScrollController();

  /// La famille sous les yeux, celle que la barre du bas met en avant.
  int _active = 0;

  /// Où commence chaque famille dans le défilement. Recalculé à chaque
  /// composition de la liste — c'est une somme de constantes, pas une mesure.
  List<double> _offsets = const [];

  /// Vrai le temps d'un saut commandé par la barre : sans ce verrou, le
  /// défilement provoqué par l'appui rallumerait au passage toutes les
  /// familles traversées.
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_jumping || !_scroll.hasClients || _offsets.isEmpty) return;
    final pixels = _scroll.position.pixels;
    var active = 0;
    for (var i = 0; i < _offsets.length; i++) {
      // Un demi-écran de tolérance : une famille compte comme « à l'écran »
      // dès que son titre a franchi le haut, pas quand elle le remplit.
      if (_offsets[i] <= pixels + 1) active = i;
    }
    if (active != _active) setState(() => _active = active);
  }

  Future<void> _goTo(int index) async {
    if (!_scroll.hasClients || index >= _offsets.length) return;
    setState(() {
      _active = index;
      _jumping = true;
    });
    await _scroll.animateTo(
      _offsets[index].clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    if (mounted) _jumping = false;
  }

  /// Insère l'emoji **au curseur**, et le retient.
  ///
  /// Au curseur et non au bout : on ajoute souvent un emoji au milieu d'une
  /// phrase déjà écrite, et le coller à la fin obligerait à le redéplacer à
  /// la main.
  void _insert(EmojiDto emoji) {
    final value = widget.controller.value;
    final selection = value.selection;

    if (!selection.isValid) {
      final text = value.text + emoji.character;
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } else {
      widget.controller.value = TextEditingValue(
        text: value.text.replaceRange(
          selection.start,
          selection.end,
          emoji.character,
        ),
        selection: TextSelection.collapsed(
          offset: selection.start + emoji.character.length,
        ),
      );
    }
    ref.read(emojiSectionsProvider.notifier).remember(emoji.character);
  }

  /// Efface **un caractère perçu**, pas une unité de code.
  ///
  /// `👨‍👩‍👧` en compte huit : reculer d'une unité laisserait derrière un
  /// morceau de famille et un caractère de jonction orphelin. C'est le
  /// découpage en graphèmes qui dit ce qu'« un caractère » veut dire.
  void _backspace() {
    final value = widget.controller.value;
    final selection = value.selection;

    if (!selection.isValid) {
      if (value.text.isEmpty) return;
      final text = value.text.characters.skipLast(1).toString();
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return;
    }
    if (!selection.isCollapsed) {
      widget.controller.value = TextEditingValue(
        text: value.text.replaceRange(selection.start, selection.end, ''),
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }
    if (selection.start == 0) return;

    final before = value.text.substring(0, selection.start);
    final kept = before.characters.skipLast(1).toString();
    widget.controller.value = TextEditingValue(
      text: kept + value.text.substring(selection.start),
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isNotEmpty) return _searchResults();

    final sections = ref.watch(emojiSectionsProvider).value ?? const [];
    if (sections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Composition de la liste **et** des positions, d'un seul passage : les
    // deux disent la même chose, et les séparer les laisserait diverger.
    final lines = <_Line>[];
    final offsets = <double>[];
    var height = 0.0;
    for (final section in sections) {
      if (section.emojis.isEmpty && !section.isRecents) continue;
      offsets.add(height);
      lines.add(_TitleLine(section.title.toUpperCase()));
      height += EmojiBoard.sectionHeaderHeight;

      if (section.emojis.isEmpty) {
        lines.add(const _EmptyLine('Vous n\'avez encore utilisé aucun emoji'));
        height += EmojiBoard.cellHeight;
        continue;
      }
      for (var i = 0; i < section.emojis.length; i += EmojiBoard.columns) {
        lines.add(
          _EmojiLine(
            section.emojis.sublist(
              i,
              (i + EmojiBoard.columns).clamp(0, section.emojis.length),
            ),
          ),
        );
        height += EmojiBoard.cellHeight;
      }
    }
    _offsets = offsets;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            key: const Key('emojiGrid'),
            controller: _scroll,
            padding: EdgeInsets.zero,
            itemCount: lines.length,
            itemBuilder: (context, index) => _line(lines[index]),
          ),
        ),
        _CategoryBar(
          titles: sections
              .where((s) => s.emojis.isNotEmpty || s.isRecents)
              .map((s) => s.title)
              .toList(growable: false),
          active: _active,
          onSelected: _goTo,
          onBackspace: _backspace,
        ),
      ],
    );
  }

  Widget _searchResults() {
    final results = ref.watch(emojiSearchProvider(widget.query));
    if (results.isEmpty) {
      return PickerMessage(text: 'Aucun emoji pour « ${widget.query} ».');
    }

    final rows = <List<EmojiDto>>[
      for (var i = 0; i < results.length; i += EmojiBoard.columns)
        results.sublist(
          i,
          (i + EmojiBoard.columns).clamp(0, results.length),
        ),
    ];
    return ListView.builder(
      key: const Key('emojiSearchResults'),
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, index) => _line(_EmojiLine(rows[index])),
    );
  }

  Widget _line(_Line line) => switch (line) {
    _TitleLine() => _SectionTitle(title: line.title),
    _EmptyLine() => SizedBox(
      height: line.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EmojiBoard.inset),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            line.text,
            key: const Key('emojiNoRecents'),
            style: TextStyle(
              fontSize: 15,
              color: context.appColors.textMuted,
            ),
          ),
        ),
      ),
    ),
    _EmojiLine() => SizedBox(
      height: line.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EmojiBoard.inset),
        child: Row(
          children: [
            for (var i = 0; i < EmojiBoard.columns; i++)
              Expanded(
                child: i < line.emojis.length
                    ? _EmojiCell(
                        emoji: line.emojis[i],
                        onTap: () => _insert(line.emojis[i]),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    ),
  };
}

/// L'en-tête d'une famille : petites capitales espacées, en gris — le même
/// traitement que « RÉCENTS » dans l'app d'origine.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: EmojiBoard.sectionHeaderHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: EmojiBoard.inset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.6,
            color: context.appColors.textMuted,
          ),
        ),
      ),
    ),
  );
}

/// Une case de la grille. Le glyphe est grand (32 dp au relevé) : c'est ce qui
/// permet de reconnaître un visage d'un coup d'œil au lieu de le déchiffrer.
class _EmojiCell extends StatelessWidget {
  const _EmojiCell({required this.emoji, required this.onTap});

  final EmojiDto emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: emoji.name,
    button: true,
    child: InkResponse(
      key: Key('emoji_${emoji.character}'),
      onTap: onTap,
      radius: EmojiBoard.cellHeight / 2,
      child: Center(
        child: Text(
          emoji.character,
          // Le glyphe **est** le libellé : le doubler pour l'accessibilité
          // ferait annoncer deux fois la même chose.
          semanticsLabel: '',
          style: const TextStyle(fontSize: EmojiBoard.glyphSize),
        ),
      ),
    ),
  );
}

/// La barre du bas : les familles à gauche, le retour arrière à droite.
///
/// Le retour arrière n'est pas dans la liste défilante des familles — il est
/// **calé** dans sa propre case (relevé) : une touche qui efface ne doit pas
/// pouvoir se dérober sous le doigt parce qu'on a fait défiler les familles.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.titles,
    required this.active,
    required this.onSelected,
    required this.onBackspace,
  });

  final List<String> titles;
  final int active;
  final ValueChanged<int> onSelected;
  final VoidCallback onBackspace;

  /// Une icône par famille, dans l'ordre de la barre.
  static const _icons = <IconData>[
    Icons.schedule,
    Icons.sentiment_satisfied_alt,
    Icons.emoji_people,
    Icons.pets,
    Icons.emoji_food_beverage,
    Icons.emoji_transportation,
    Icons.emoji_events,
    Icons.lightbulb_outline,
    Icons.emoji_symbols,
    Icons.flag_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: EmojiBoard.categoryBarHeight,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: titles.length,
              itemBuilder: (context, index) {
                final selected = index == active;
                return SizedBox(
                  width: EmojiBoard.categoryBarHeight,
                  child: Center(
                    child: InkResponse(
                      key: Key('emojiCategory_$index'),
                      onTap: () => onSelected(index),
                      radius: EmojiBoard.categoryIndicatorSize / 2,
                      child: Container(
                        height: EmojiBoard.categoryIndicatorSize,
                        width: EmojiBoard.categoryIndicatorSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? colors.accentSoft
                              : Colors.transparent,
                        ),
                        child: Icon(
                          _icons[index % _icons.length],
                          size: EmojiBoard.categoryIconSize,
                          color: selected ? colors.accent : colors.textMuted,
                          semanticLabel: titles[index],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: EmojiBoard.categoryBarHeight,
            child: Center(
              child: InkResponse(
                key: const Key('emojiBackspace'),
                onTap: onBackspace,
                radius: EmojiBoard.categoryIndicatorSize / 2,
                child: Icon(
                  Icons.backspace_outlined,
                  size: EmojiBoard.categoryIconSize,
                  color: colors.textMuted,
                  semanticLabel: 'Retour arrière',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
