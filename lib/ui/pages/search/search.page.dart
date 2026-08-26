import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/core/application/services/search.service.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/pages/conversations/widgets/conversation_tile.widget.dart';
import 'package:messages/ui/pages/search/providers/search.provider.dart';
import 'package:messages/ui/pages/search/widgets/message_hit_tile.widget.dart';
import 'package:messages/ui/pages/search/widgets/search_field.widget.dart';
import 'package:messages/ui/pages/search/widgets/search_filter_grid.widget.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/content_panel.widget.dart';

/// Recherche : les conversations d'abord, puis les messages, comme Google
/// Messages.
///
/// Tant que rien n'est tapé, l'écran propose les filtres — c'est là que
/// l'app d'origine les loge, pas sur l'écran d'accueil. Filtre et requête
/// s'excluent : choisir l'un efface l'autre.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _query = TextEditingController();
  ConversationFilter? _filter;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Taper efface le filtre : les deux se répondent, l'écran n'en montre
  /// qu'un à la fois.
  void _onQueryChanged(String value) {
    setState(() {
      if (value.isNotEmpty) _filter = null;
    });
  }

  void _onFilterSelected(ConversationFilter? filter) {
    setState(() {
      _filter = filter;
      if (filter != null) _query.clear();
    });
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
              onChanged: _onQueryChanged,
              onClearQuery: () => setState(_query.clear),
              onBack: () => context.pop(),
              filterLabel: switch (_filter) {
                ConversationFilter.unread => 'Non lues',
                ConversationFilter.archived => 'Archivées',
                _ => null,
              },
              onClearFilter: () => _onFilterSelected(null),
            ),
            Expanded(child: _body(query)),
          ],
        ),
      ),
    );
  }

  Widget _body(String query) {
    if (_filter != null) {
      return ContentPanel(child: _FilteredConversations(filter: _filter!));
    }
    if (query.isEmpty) {
      return SearchFilterGrid(onSelected: _onFilterSelected);
    }
    if (query.length < SearchService.minQueryLength) return const _Hint();

    final resultsAsync = ref.watch(searchResultsProvider(query));
    return ContentPanel(
      child: resultsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (results) =>
            results.isEmpty ? _NoResults(query: query) : _Results(results: results),
      ),
    );
  }
}

/// Les fils retenus par un filtre, présentés comme sur l'écran d'accueil.
class _FilteredConversations extends ConsumerWidget {
  const _FilteredConversations({required this.filter});

  final ConversationFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(conversationsProvider(filter: filter));

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur : $error')),
      data: (conversations) => conversations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  switch (filter) {
                    ConversationFilter.unread => 'Tout est lu.',
                    ConversationFilter.archived =>
                      'Aucune conversation archivée.',
                    ConversationFilter.all => 'Aucune conversation.',
                  },
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) => ConversationTile(
                conversation: conversations[index],
                onTap: () => context.push(
                  AppRoutes.thread(conversations[index].threadId),
                ),
              ),
            ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final SearchResultsDto results;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (results.conversations.isNotEmpty) ...[
          const _SectionHeader('Conversations'),
          ...results.conversations.map(
            (conversation) => ConversationTile(
              conversation: conversation,
              onTap: () => context.push(AppRoutes.thread(conversation.threadId)),
            ),
          ),
        ],
        if (results.messages.isNotEmpty) ...[
          const _SectionHeader('Messages'),
          ...results.messages.map(
            (hit) => MessageHitTile(
              hit: hit,
              query: results.query,
              onTap: () => context.push(AppRoutes.thread(hit.message.threadId)),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          color: colors.accent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Text(
        'Saisissez au moins ${SearchService.minQueryLength} caractères.',
        style: TextStyle(color: colors.textMuted),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Aucun résultat pour « $query ».',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }
}
