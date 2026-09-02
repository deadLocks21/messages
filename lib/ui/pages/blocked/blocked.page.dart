import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/pages/conversations/widgets/conversation_tile.widget.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/content_panel.widget.dart';

/// « Spam et bloqués » : les fils dont un correspondant est dans la liste
/// bloquée du système.
///
/// Rien n'a été supprimé — c'est ce que promet le dialogue de blocage, et
/// c'est pour ça que cet écran existe : les messages continuent d'arriver dans
/// le stock, ils cessent seulement de notifier et de tenir la liste
/// principale.
class BlockedPage extends ConsumerWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final async = ref.watch(
      conversationsProvider(filter: ConversationFilter.blocked),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(toolbarHeight: 64, title: const Text('Spam et bloqués')),
      body: ContentPanel(
        child: async.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Erreur : $error')),
          data: (conversations) => conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Aucun numéro bloqué.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ConversationTile(
                      conversation: conversation,
                      onTap: () => context.push(
                        AppRoutes.thread(conversation.threadId),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
