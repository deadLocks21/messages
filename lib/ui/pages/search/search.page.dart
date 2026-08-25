import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/core/application/services/search.service.dart';
import 'package:messages/ui/pages/conversations/widgets/conversation_tile.widget.dart';
import 'package:messages/ui/pages/search/widgets/message_hit_tile.widget.dart';
import 'package:messages/ui/pages/search/providers/search.provider.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Recherche : les conversations d'abord, puis les messages, comme Google
/// Messages.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
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
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('searchField'),
          controller: _query,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Rechercher dans les conversations',
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 17),
          ),
          style: TextStyle(color: colors.textPrimary, fontSize: 17),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_query.clear),
            ),
        ],
      ),
      body: query.length < SearchService.minQueryLength
          ? const _Hint()
          : resultsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur : $error')),
              data: (results) =>
                  results.isEmpty ? _NoResults(query: query) : _Results(results: results),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
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
