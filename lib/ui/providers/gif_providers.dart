import 'package:messages/core/application/dtos/gif.dto.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/gif.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gif_providers.g.dart';

/// Ce que montre la grille pour un terme donné — vide pour les GIF mis en
/// avant.
///
/// Le contrôleur garde les [Gif] du **domaine** et n'expose que des DTO, comme
/// le plateau de pièces jointes garde ses brouillons. Il faut bien qu'ils
/// vivent quelque part : la grille ne connaît qu'un identifiant, alors que
/// l'envoi a besoin de toutes les déclinaisons pour choisir la bonne taille.
///
/// La grille est **sans fin** : chaque page apporte sa position de reprise, et
/// [loadMore] la suit. Une page sans position est la dernière.
@riverpod
class GifFeed extends _$GifFeed {
  final List<Gif> _gifs = [];
  String? _cursor;

  /// Un chargement de page suivante est-il en cours ? Sans ce verrou, un
  /// défilement rapide en demanderait trois d'affilée et la grille se
  /// répéterait.
  bool _loadingMore = false;

  @override
  Future<GifPageDto> build(String query) async {
    _gifs.clear();
    _cursor = null;
    final catalog = ref.watch(gifCatalogProvider);
    final page = query.trim().isEmpty
        ? await catalog.featured()
        : await catalog.search(query.trim());
    return _absorb(page);
  }

  /// Ajoute la page suivante à ce qui est déjà affiché.
  ///
  /// Ne remplace jamais l'état par un `AsyncLoading` : la grille ne doit pas
  /// se vider sous le doigt qui la fait défiler. Une page suivante qui échoue
  /// ne casse rien non plus — ce qui est affiché reste affiché, et le
  /// catalogue a déjà journalisé la panne.
  Future<void> loadMore() async {
    final current = state.value;
    if (_loadingMore || !_hasMore || current == null) return;
    _loadingMore = true;
    state = AsyncData(current.loading(true));
    try {
      final catalog = ref.read(gifCatalogProvider);
      final page = query.trim().isEmpty
          ? await catalog.featured(cursor: _cursor)
          : await catalog.search(query.trim(), cursor: _cursor);
      state = AsyncData(_absorb(page));
    } catch (_) {
      state = AsyncData(current.loading(false));
    } finally {
      _loadingMore = false;
    }
  }

  /// Télécharge le GIF [gifId] à la taille qui tient dans le MMS, et rend le
  /// brouillon prêt à poser sur le plateau.
  ///
  /// Propage les refus du domaine (aucune déclinaison assez légère, réseau
  /// absent) : c'est la page qui sait comment les dire.
  Future<AttachmentDraft> draftFor(String gifId) {
    final gif = _gifs.firstWhere((g) => g.id == gifId);
    return ref.read(pickGifUseCaseProvider).execute(gif);
  }

  bool get _hasMore => _cursor != null && _cursor!.isNotEmpty;

  GifPageDto _absorb(GifPage page) {
    // Un catalogue sert parfois deux fois le même résultat à cheval sur deux
    // pages : une clé en double ferait lever la grille.
    for (final gif in page.gifs) {
      if (!_gifs.contains(gif)) _gifs.add(gif);
    }
    _cursor = page.cursor;
    return GifPageDto(
      gifs: _gifs.map(GifDto.fromDomain).toList(growable: false),
      hasMore: _hasMore,
    );
  }
}
