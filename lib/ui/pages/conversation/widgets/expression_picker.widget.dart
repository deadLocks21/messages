import 'dart:async';

import 'package:flutter/material.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/pages/conversation/widgets/emoji_board.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/gif_grid.widget.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Ce que le panneau montre. Deux onglets, comme l'app d'origine en montre
/// trois — le troisième, « Autocollants », relève du RCS et n'est pas repris :
/// un onglet mort ferait une capture plus ressemblante et une app qui promet
/// ce qu'elle ne tient pas.
enum ExpressionTab {
  emoji('Emoji', 'Rechercher des emoji'),
  gif('GIF', 'Rechercher des GIF');

  final String label;

  /// Le champ de recherche est **partagé** par les deux onglets — un seul
  /// champ, à la même place — mais il ne cherche pas la même chose. C'est son
  /// libellé qui le dit.
  final String searchHint;

  const ExpressionTab(this.label, this.searchHint);
}

/// Le panneau des emoji et des GIF, sous le champ de rédaction.
///
/// Il se pose là où se pose celui de l'enregistrement — **sous** le champ et
/// non par-dessus : dans l'app d'origine, l'ouvrir pousse le fil vers le haut
/// sans jamais masquer ce qu'on vient d'écrire.
///
/// Relevé sur l'émulateur (1080 × 2400, 420 dpi — les dp sont les pixels
/// divisés par 2,625). Les deux onglets **partagent exactement le même
/// en-tête**, et c'est ce qui fait qu'on passe de l'un à l'autre sans que rien
/// bouge :
///
/// | Élément | Relevé |
/// |---|---|
/// | En-tête | 112 dp : 8 + onglets 40 + 8 + recherche 48 + 8 |
/// | Onglets | 40 dp, pilules pleines, segments égaux, 1,5 dp entre eux |
/// | Recherche | boîte de 48 dp, pilule de 40 dp, loupe dans un carré de 48 dp calé à gauche |
/// | Panneau | 282 dp à l'ouverture, dépliable jusqu'à 686 dp sur un écran de 914 |
///
/// **Il se referme par le bouton qui l'a ouvert.** Dans l'app d'origine, le
/// bouton emoji du champ de rédaction est un interrupteur — son libellé
/// d'accessibilité passe de « Afficher » à « Masquer » — et c'est le geste le
/// plus court : la main est déjà là. Le glissé vers le bas le referme aussi,
/// comme une feuille modale, mais il faut d'abord l'avoir replié — et il se
/// prend sur la **rangée de recherche**, pas sur les onglets : un glissé qui
/// part d'un onglet finit par le sélectionner au passage.
class ExpressionPicker extends StatefulWidget {
  const ExpressionPicker({
    super.key,
    required this.threadId,
    required this.controller,
    required this.initialTab,
    required this.onPicked,
    required this.onError,
    required this.onClose,
  });

  final String threadId;

  /// Le champ de rédaction : un emoji s'insère au curseur, et la touche de
  /// retour arrière efface devant lui. Le panneau écrit donc **dans** le
  /// champ, il ne lui renvoie pas des caractères à recoller.
  final TextEditingController controller;

  /// L'onglet ouvert au départ : celui de l'emoji quand on vient du bouton du
  /// champ, celui du GIF quand on vient du panneau des sources.
  final ExpressionTab initialTab;

  /// Le GIF est téléchargé et prêt : à la page de le poser sur le plateau.
  final ValueChanged<AttachmentDraft> onPicked;

  /// Ce que le panneau ne sait pas dire lui-même : un catalogue injoignable,
  /// un GIF trop lourd pour le MMS.
  final ValueChanged<Object> onError;

  /// Le panneau s'en va — tiré vers le bas, ou son GIF choisi.
  final VoidCallback onClose;

  /// Hauteur à l'ouverture. Relevé : 282 dp, à peu près celle d'un clavier —
  /// c'est la place qu'il prend, et le panneau la reprend.
  static const collapsedHeight = 282.0;

  /// Ce que le panneau occupe une fois déplié, en part de l'écran. Relevé :
  /// 686 dp sur 914, le fil se réduisant à une bulle tronquée. Une part
  /// plutôt qu'une hauteur, sinon un petit écran n'aurait plus de fil du tout.
  static const expandedFraction = 0.75;

  static const padding = 8.0;
  static const tabRowHeight = 40.0;
  static const tabGap = 2.0;
  static const searchRowHeight = 48.0;
  static const searchFieldHeight = 40.0;
  static const chipRowHeight = 48.0;
  static const chipHeight = 32.0;
  static const chipRadius = 8.0;
  static const tileRadius = 8.0;
  static const columns = 2;

  /// Ce qu'il faut tirer pour déplier ou replier. Assez pour qu'un
  /// défilement de la grille ne le déclenche pas par accident.
  static const dragThreshold = 24.0;

  /// À quelle distance du bas la page suivante de GIF est demandée. Deux
  /// vignettes d'avance : de quoi arriver avant le doigt.
  static const loadMoreExtent = 600.0;

  @override
  State<ExpressionPicker> createState() => _ExpressionPickerState();
}

class _ExpressionPickerState extends State<ExpressionPicker> {
  final TextEditingController _search = TextEditingController();

  late ExpressionTab _tab = widget.initialTab;

  /// Ce qui est réellement cherché. Distinct du texte tapé : la frappe court
  /// plus vite que le réseau.
  String _query = '';
  bool _expanded = false;

  /// Ce que le doigt a parcouru depuis qu'il s'est posé sur l'en-tête.
  double _dragged = 0;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Changer d'onglet **vide la recherche** : « chien » ne veut pas dire la
  /// même chose dans une table d'emoji et dans un catalogue de GIF, et garder
  /// le terme laisserait croire que le second onglet n'a rien trouvé.
  void _onTab(ExpressionTab tab) {
    if (tab == _tab) return;
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _tab = tab;
      _query = '';
    });
  }

  /// La recherche part **quand la frappe s'arrête**, mais seulement du côté
  /// des GIF.
  ///
  /// Le délai n'existe qu'à cause du réseau : sans lui, « chat » lancerait
  /// quatre requêtes dont trois seraient jetées, et la grille clignoterait à
  /// chaque lettre. La table des emoji, elle, est en mémoire — la faire
  /// attendre ne protégerait rien et rendrait la frappe molle.
  void _onSearch(String value) {
    final query = value.trim();
    _debounce?.cancel();
    if (_query == query) return;

    if (_tab == ExpressionTab.emoji) {
      setState(() => _query = query);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _query == query) return;
      setState(() => _query = query);
    });
  }

  void _onCategory(String query) {
    _debounce?.cancel();
    _search.text = query;
    setState(() => _query = query);
  }

  /// Le panneau se déplie et se replie au doigt, et se referme d'un dernier
  /// glissé vers le bas.
  ///
  /// C'est la distance **parcourue** qui décide, et non celle d'un événement :
  /// un glissé fluide arrive par paquets de trois pixels, dont aucun
  /// n'atteindrait jamais le seuil à lui seul.
  void _onDragStart(DragStartDetails _) => _dragged = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    _dragged += details.primaryDelta ?? 0;

    if (_dragged <= -ExpressionPicker.dragThreshold && !_expanded) {
      _dragged = 0;
      setState(() => _expanded = true);
      return;
    }
    if (_dragged >= ExpressionPicker.dragThreshold) {
      _dragged = 0;
      if (_expanded) {
        setState(() => _expanded = false);
      } else {
        widget.onClose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final height = _expanded
        ? MediaQuery.sizeOf(context).height * ExpressionPicker.expandedFraction
        : ExpressionPicker.collapsedHeight;

    return AnimatedContainer(
      key: const Key('expressionPicker'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      color: colors.background,
      child: Column(
        children: [
          _Tabs(current: _tab, onSelected: _onTab),
          // La préhension est sur la **rangée de recherche**, pas sur les
          // onglets : un glissé qui part d'un onglet finit par le sélectionner
          // au passage, et on se retrouve sur les GIF pour avoir voulu
          // agrandir les emoji. La rangée en dessous ne porte qu'un champ de
          // texte, qu'un glissé vertical n'intéresse pas.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            child: _SearchField(
              controller: _search,
              hint: _tab.searchHint,
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: switch (_tab) {
              ExpressionTab.emoji => EmojiBoard(
                controller: widget.controller,
                query: _query,
              ),
              ExpressionTab.gif => GifBody(
                query: _query,
                onPicked: widget.onPicked,
                onError: widget.onError,
                onClose: widget.onClose,
                onCategory: _onCategory,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Les onglets, en `SegmentedButton` — le composant Material de « choisir
/// l'un des deux ».
///
/// C'est bien ce que fait l'app d'origine, et le composant apporte ce qu'un
/// couple de pilules bricolées n'avait pas : le rôle d'accessibilité
/// `radio` sur chaque segment, l'annonce de la sélection, la navigation au
/// clavier. Les couleurs, elles, restent celles du relevé — `accent` sur le
/// segment choisi, `surface` sur l'autre.
///
/// - `expandedInsets: EdgeInsets.zero` : sans lui, le composant se règle sur
///   son contenu et « Emoji » serait plus étroit que « GIF ». Le relevé donne
///   des segments **égaux**, occupant toute la largeur.
/// - `showSelectedIcon: false` : Material coche le segment choisi, l'app
///   d'origine non — et la coche pousserait le libellé hors de son segment.
/// - Pas de liseré : le relevé n'en montre aucun, les deux fonds suffisent à
///   dire lequel est choisi.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.current, required this.onSelected});

  final ExpressionTab current;
  final ValueChanged<ExpressionTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExpressionPicker.padding,
        ExpressionPicker.padding,
        ExpressionPicker.padding,
        0,
      ),
      child: SizedBox(
        height: ExpressionPicker.tabRowHeight,
        child: SegmentedButton<ExpressionTab>(
          segments: [
            for (final tab in ExpressionTab.values)
              ButtonSegment(
                value: tab,
                label: Text(tab.label, key: Key('expressionTab_${tab.name}')),
              ),
          ],
          selected: {current},
          onSelectionChanged: (selection) => onSelected(selection.first),
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.accent
                  : colors.surface,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.onAccent
                  : colors.textPrimary,
            ),
            side: const WidgetStatePropertyAll(BorderSide.none),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            // Sans cela, Material réserve 48 dp de zone tactile et la rangée
            // de 40 dp du relevé grandirait de huit pixels.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

/// Le champ de recherche, épinglé sous les onglets.
///
/// La loupe occupe un carré de 48 dp calé au bord gauche de la pilule (relevé)
/// : c'est ce qui donne au texte son retrait, sans padding arbitraire.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.all(ExpressionPicker.padding),
      child: SizedBox(
        height: ExpressionPicker.searchRowHeight,
        child: Center(
          child: Container(
            key: const Key('expressionSearchPill'),
            height: ExpressionPicker.searchFieldHeight,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(
                ExpressionPicker.searchFieldHeight / 2,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: ExpressionPicker.searchRowHeight,
                  child: Icon(Icons.search, size: 24, color: colors.textPrimary),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('expressionSearchField'),
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    // Les deux ensemble, et pas l'un sans l'autre : le padding
                    // par défaut d'un champ dense pose le texte contre le haut
                    // de sa boîte, et le centrage n'a d'effet qu'une fois ce
                    // padding retiré. Sans les deux, le texte se lit cinq
                    // points au-dessus du centre de la pilule (relevé).
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ce que le panneau dit quand il n'a rien à montrer. Partagé par les deux
/// onglets : une grille vide se dit de la même façon, qu'elle soit vide faute
/// de réseau ou faute de correspondance.
class PickerMessage extends StatelessWidget {
  const PickerMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        key: const Key('pickerEmpty'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: context.appColors.textMuted),
      ),
    ),
  );
}
