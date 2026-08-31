import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/gif.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/pages/conversation/widgets/expression_picker.widget.dart';
import 'package:messages/ui/providers/gif_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// L'onglet GIF : les puces, la grille, et ce qui se passe quand on en touche
/// un.
class GifBody extends ConsumerStatefulWidget {
  const GifBody({
    super.key,
    required this.query,
    required this.onPicked,
    required this.onError,
    required this.onClose,
    required this.onCategory,
  });

  final String query;
  final ValueChanged<AttachmentDraft> onPicked;
  final ValueChanged<Object> onError;
  final VoidCallback onClose;

  /// Une puce touchée remplit le champ de recherche partagé : ce qui est
  /// cherché doit se lire.
  final ValueChanged<String> onCategory;

  @override
  ConsumerState<GifBody> createState() => _GifBodyState();
}

class _GifBodyState extends ConsumerState<GifBody> {
  final ScrollController _scroll = ScrollController();

  /// Le GIF dont on attend le téléchargement. Un seul à la fois — deux pièces
  /// jointes pour un seul appui n'auraient aucun sens.
  String? _downloading;

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
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining > ExpressionPicker.loadMoreExtent) return;
    ref.read(gifFeedProvider(widget.query).notifier).loadMore();
  }

  /// Télécharge le GIF touché, puis le rend à la page.
  ///
  /// **Un appui joint, il n'envoie pas.** L'app d'origine ne montre pas d'étape
  /// intermédiaire — pas d'aperçu, pas de confirmation — et celle-ci non plus :
  /// le GIF part sur le plateau, exactement comme un vocal qu'on vient
  /// d'enregistrer, et c'est le champ de rédaction qui garde le dernier mot.
  /// C'est ce qui laisse ajouter une légende, retirer le GIF, ou en choisir un
  /// autre — et ce qui fait qu'un appui de trop ne coûte pas un MMS.
  Future<void> _onTap(GifDto gif) async {
    if (_downloading != null) return;
    setState(() => _downloading = gif.id);
    try {
      final draft = await ref
          .read(gifFeedProvider(widget.query).notifier)
          .draftFor(gif.id);
      if (!mounted) return;
      widget.onPicked(draft);
      widget.onClose();
    } catch (error) {
      if (!mounted) return;
      widget.onError(error);
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(gifFeedProvider(widget.query));

    return feed.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      // Le catalogue est au bout du réseau : hors ligne, il n'y a pas de GIF,
      // et ce n'est pas une panne de l'app. On le dit là où on le regarde.
      error: (_, _) => const PickerMessage(
        text: 'Les GIF ne sont pas disponibles pour le moment.',
      ),
      data: (page) {
        if (page.gifs.isEmpty) {
          return PickerMessage(
            text: widget.query.isEmpty
                ? 'Aucun GIF à afficher.'
                : 'Aucun GIF pour « ${widget.query} ».',
          );
        }
        return GifGrid(
          gifs: page.gifs,
          categories: ref.watch(gifCategoriesProvider).value ?? const [],
          scroll: _scroll,
          loadingMore: page.loadingMore,
          downloading: _downloading,
          onTap: _onTap,
          onCategory: (category) => widget.onCategory(category.query),
        );
      },
    );
  }
}

/// La grille **en quinconce** : deux colonnes indépendantes, chaque vignette à
/// son rapport d'aspect.
///
/// Écrite à la main, sans paquet tiers : la hauteur de chaque vignette est
/// connue d'avance (le catalogue publie les dimensions de l'aperçu), il n'y a
/// donc rien à mesurer et rien à réagencer — un GIF va dans la colonne la plus
/// courte, et c'est tout l'algorithme.
///
/// **Toutes les vignettes existent, seules celles qu'on approche s'animent.**
/// Un défilement sans fin finit par en aligner cent, et cent GIF qui décodent
/// une image toutes les cinquante millisecondes occuperaient le processeur à
/// ne rien montrer — Flutter ne suspend pas une image devenue invisible. Les
/// positions étant déjà calculées, savoir laquelle est proche de l'écran ne
/// coûte qu'une comparaison ; la marge d'une hauteur d'écran de part et
/// d'autre fait que la bascule se joue toujours hors du champ.
class GifGrid extends StatefulWidget {
  const GifGrid({
    super.key,
    required this.gifs,
    required this.categories,
    required this.scroll,
    required this.loadingMore,
    required this.downloading,
    required this.onTap,
    required this.onCategory,
  });

  final List<GifDto> gifs;
  final List<GifCategoryDto> categories;
  final ScrollController scroll;
  final bool loadingMore;
  final String? downloading;
  final ValueChanged<GifDto> onTap;
  final ValueChanged<GifCategoryDto> onCategory;

  /// De combien il faut avoir défilé pour reconsidérer ce qui s'anime. Assez
  /// pour ne pas recalculer à chaque image, assez peu pour que la marge d'une
  /// hauteur d'écran ne soit jamais épuisée.
  static const repaintStep = 200.0;

  @override
  State<GifGrid> createState() => _GifGridState();
}

class _GifGridState extends State<GifGrid> {
  /// Le dernier décalage sur lequel la répartition a été décidée.
  double _offset = 0;

  bool _onScroll(ScrollNotification notification) {
    final pixels = notification.metrics.pixels;
    if ((pixels - _offset).abs() < GifGrid.repaintStep) return false;
    setState(() => _offset = pixels);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = ExpressionPicker.padding;
        final width =
            (constraints.maxWidth - gutter * (ExpressionPicker.columns + 1)) /
            ExpressionPicker.columns;

        // Répartition : chaque GIF rejoint la colonne la plus courte. Les
        // hauteurs se cumulent au fil de l'eau, sans jamais avoir à mesurer un
        // widget — et ce cumul est aussi l'ordonnée de la vignette, celle qui
        // dit si elle est proche de l'écran.
        final columns = List.generate(
          ExpressionPicker.columns,
          (_) => <({GifDto gif, double top, double height})>[],
        );
        final heights = List.filled(ExpressionPicker.columns, 0.0);
        for (final gif in widget.gifs) {
          var shortest = 0;
          for (var i = 1; i < heights.length; i++) {
            if (heights[i] < heights[shortest]) shortest = i;
          }
          final height = width / gif.aspectRatio;
          columns[shortest].add((
            gif: gif,
            top: heights[shortest],
            height: height,
          ));
          heights[shortest] += height + gutter;
        }

        // Ce qui précède la grille dans le défilement : les puces, quand il y
        // en a. Sans ce décalage, la fenêtre du calcul serait fausse d'une
        // rangée — assez peu pour se perdre dans la marge, mais autant le
        // poser juste.
        final headerHeight = widget.categories.isEmpty
            ? 0.0
            : ExpressionPicker.chipRowHeight;
        final margin = constraints.maxHeight;
        final from = _offset - headerHeight - margin;
        final to = _offset - headerHeight + constraints.maxHeight + margin;

        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: SingleChildScrollView(
            key: const Key('gifGrid'),
            controller: widget.scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Un catalogue qui ne publie pas de puces ne laisse pas une
                // bande vide : la grille remonte contre le champ de recherche.
                if (widget.categories.isNotEmpty)
                  _Categories(
                    categories: widget.categories,
                    onSelected: widget.onCategory,
                  ),
                Padding(
                  padding: const EdgeInsets.all(gutter),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns.length; i++) ...[
                        if (i > 0) const SizedBox(width: gutter),
                        Expanded(
                          child: Column(
                            children: [
                              for (final placed in columns[i]) ...[
                                _GifTile(
                                  gif: placed.gif,
                                  animated:
                                      placed.top + placed.height >= from &&
                                      placed.top <= to,
                                  downloading:
                                      widget.downloading == placed.gif.id,
                                  onTap: () => widget.onTap(placed.gif),
                                ),
                                const SizedBox(height: gutter),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.loadingMore)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Les puces de recherche toute faite. Premier élément de la grille, et non de
/// l'en-tête : elles défilent avec les GIF (relevé).
class _Categories extends StatelessWidget {
  const _Categories({required this.categories, required this.onSelected});

  final List<GifCategoryDto> categories;
  final ValueChanged<GifCategoryDto> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: ExpressionPicker.chipRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ExpressionPicker.padding,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: ExpressionPicker.padding),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Center(
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ExpressionPicker.chipRadius),
                side: BorderSide(color: colors.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('gifCategory_${category.query}'),
                onTap: () => onSelected(category),
                child: Container(
                  height: ExpressionPicker.chipHeight,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    category.label,
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Une vignette : le GIF, à son rapport d'aspect, et rien autour.
///
/// Pas de fond derrière, pas de liseré — comme une image dans une bulle,
/// l'image **est** la vignette.
class _GifTile extends StatelessWidget {
  const _GifTile({
    required this.gif,
    required this.animated,
    required this.downloading,
    required this.onTap,
  });

  final GifDto gif;

  /// La vignette est-elle assez proche de l'écran pour valoir un décodage ?
  final bool animated;

  final bool downloading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: gif.description,
      button: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ExpressionPicker.tileRadius),
        child: AspectRatio(
          aspectRatio: gif.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GifPreview(gif: gif, colors: colors, animated: animated),
              // Le témoin remplace la vignette au lieu de s'ajouter à côté :
              // ce qui est en train d'être téléchargé, c'est celui-là.
              if (downloading)
                ColoredBox(
                  color: colors.background.withValues(alpha: 0.7),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('gif_${gif.id}'),
                  onTap: downloading ? null : onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'aperçu animé, et ce qui l'attend.
///
/// `Image.network` anime les GIF **et les WebP** sans aide, et partage le
/// cache d'images de Flutter : une grille qui redescend ne retélécharge rien.
///
/// Ce qui se peint pendant le téléchargement n'est pas un rectangle uni mais
/// l'**image floue** que le catalogue publie avec chaque résultat, quelques
/// centaines d'octets déjà encodés en base64. La vignette a donc tout de suite
/// les bonnes couleurs, et l'arrivée du GIF ne fait pas surgir une image là où
/// il n'y avait rien.
///
/// Le catalogue simulé, lui, ne sert ni l'un ni l'autre — ses adresses sont en
/// `demo:` — et la pastille dit ce que le GIF montrerait. C'est le même parti
/// que la silhouette d'un son hors Android : rien d'inventé qui se ferait
/// passer pour vrai.
class _GifPreview extends StatelessWidget {
  const _GifPreview({
    required this.gif,
    required this.colors,
    required this.animated,
  });

  final GifDto gif;
  final AppColors colors;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    // Loin de l'écran, la vignette garde sa place mais pas son image : c'est
    // ce qui permet à la grille de défiler sans fin.
    if (!animated) return _placeholder(withLabel: false);
    if (!gif.previewUrl.startsWith('http')) {
      return _placeholder(withLabel: true);
    }

    return Image.network(
      gif.previewUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(withLabel: false),
      errorBuilder: (_, _, _) => _placeholder(withLabel: true),
    );
  }

  Widget _placeholder({required bool withLabel}) {
    final blur = _blurBytes;
    if (blur != null) {
      return Image.memory(blur, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return ColoredBox(
      color: colors.surface,
      child: withLabel
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  gif.description,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                ),
              ),
            )
          : null,
    );
  }

  /// Les octets de l'image floue, décodés une fois par identifiant.
  ///
  /// Sans ce cache, chaque image de la grille redécoderait le base64 de toutes
  /// les vignettes en attente — et une vignette reste en attente le temps que
  /// son GIF descende.
  Uint8List? get _blurBytes {
    final raw = gif.blurPreview;
    if (raw == null) return null;
    return _blurCache.putIfAbsent(gif.id, () {
      final comma = raw.indexOf(',');
      if (comma < 0) return null;
      try {
        return base64Decode(raw.substring(comma + 1));
      } catch (_) {
        // Une image floue illisible n'est pas une panne : la vignette se
        // rabat sur son fond uni.
        return null;
      }
    });
  }

  static final Map<String, Uint8List?> _blurCache = {};
}
