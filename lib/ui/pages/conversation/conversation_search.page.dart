import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/core/application/services/search.service.dart';
import 'package:messages/ui/pages/search/providers/search.provider.dart';
import 'package:messages/ui/pages/search/widgets/message_hit_tile.widget.dart';
import 'package:messages/ui/pages/search/widgets/search_field.widget.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/content_panel.widget.dart';

/// « Rechercher dans la conversation » : la recherche de l'écran d'accueil,
/// mais bornée à un fil.
///
/// Elle ne propose donc **ni filtres ni fils** — le fil est déjà choisi, il ne
/// reste que des messages. Chaque ligne dit qui a écrit, quand, et l'extrait
/// avec le terme surligné ; un appui ramène au fil, **à ce message**.
class ConversationSearchPage extends ConsumerStatefulWidget {
  const ConversationSearchPage({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ConversationSearchPage> createState() =>
      _ConversationSearchPageState();
}

class _ConversationSearchPageState
    extends ConsumerState<ConversationSearchPage> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final query = _query.text.trim();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            SearchField(
              controller: _query,
              hintText: 'Rechercher dans la conversation',
              onChanged: (_) => setState(() {}),
              onClearQuery: () => setState(_query.clear),
              onBack: () => context.pop(),
            ),
            Expanded(child: _body(query)),
          ],
        ),
      ),
    );
  }

  Widget _body(String query) {
    // Le champ vide n'est pas un résultat vide : tant qu'on n'a rien tapé, il
    // n'y a rien à dire, et surtout pas « aucun message ».
    if (query.isEmpty) return const SizedBox.shrink();
    if (query.length < SearchService.minQueryLength) {
      return const _Hint();
    }

    final async = ref.watch(
      threadSearchResultsProvider(widget.threadId, query),
    );
    return ContentPanel(
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (hits) => hits.isEmpty
            ? _NoResults(query: query)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: hits.length,
                itemBuilder: (context, index) => MessageHitTile(
                  hit: hits[index],
                  query: query,
                  onTap: () => _reveal(hits[index]),
                ),
              ),
      ),
    );
  }

  /// Retour au fil, sur le message trouvé.
  ///
  /// `go` et non `pop` : la recherche s'ouvre depuis l'écran de détails, et
  /// dépiler une fois ramènerait là, pas à la conversation.
  void _reveal(MessageHitDto hit) => context.go(
    AppRoutes.thread(widget.threadId),
    extra: hit.message.id,
  );
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Tapez au moins ${SearchService.minQueryLength} caractères.',
      style: TextStyle(color: context.appColors.textMuted),
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'Aucun message ne contient « $query » dans cette conversation.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.appColors.textMuted),
      ),
    ),
  );
}
