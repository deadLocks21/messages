import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/pages/conversations/widgets/conversation_tile.widget.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Les fils archivés : retirés de la liste principale, mais intacts.
class ArchivedPage extends ConsumerWidget {
  const ArchivedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final archivedAsync = ref.watch(
      conversationsProvider(filter: ConversationFilter.archived),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Archivées')),
      body: archivedAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (conversations) => conversations.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Aucune conversation archivée.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textMuted),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return Dismissible(
                    key: Key('unarchive_${conversation.threadId}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: colors.accentSoft,
                      padding: const EdgeInsets.only(right: 24),
                      child: Icon(Icons.unarchive, color: colors.onAccentSoft),
                    ),
                    onDismissed: (_) async {
                      await ref
                          .read(updateConversationFlagsUseCaseProvider)
                          .toggleArchived(conversation.threadId);
                      ref.invalidate(conversationsProvider);
                    },
                    child: ConversationTile(
                      conversation: conversation,
                      onTap: () =>
                          context.push(AppRoutes.thread(conversation.threadId)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
