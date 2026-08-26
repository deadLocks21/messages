import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/ui/pages/conversations/widgets/conversation_tile.widget.dart';
import 'package:messages/ui/pages/conversations/widgets/default_app_banner.widget.dart';
import 'package:messages/ui/pages/conversations/widgets/messages_app_bar.widget.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/content_panel.widget.dart';

/// Écran d'accueil : la barre du haut, la liste des fils dans son panneau, et
/// le bouton « Démarrer une discussion ».
///
/// Les filtres ne sont pas ici mais dans l'écran de recherche, comme dans
/// Google Messages. L'appui long ouvre le mode sélection (archiver, épingler,
/// supprimer…).
class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  final Set<String> _selection = {};

  bool get _selecting => _selection.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversationsAsync = ref.watch(conversationsProvider());
    final access = ref.watch(smsAccessControllerProvider).value;

    return Scaffold(
      backgroundColor: colors.background,
      // En sélection, la barre du haut laisse la place à la barre d'actions :
      // c'est le fil sélectionné qui compte.
      appBar: _selecting ? _selectionAppBar(context) : const MessagesAppBar(),
      body: Column(
        children: [
          if (!_selecting && access != null && !access.canCompose)
            const DefaultAppBanner(),
          Expanded(
            child: ContentPanel(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(conversationsProvider),
                child: conversationsAsync.when(
                  // Un SMS reçu recharge la liste : sans ceci elle clignoterait
                  // à chaque événement du stock.
                  skipLoadingOnReload: true,
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorState(error: '$error'),
                  data: (conversations) => conversations.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 104),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            return ConversationTile(
                              conversation: conversation,
                              selected: _selection.contains(conversation.threadId),
                              onTap: () => _open(conversation),
                              onLongPress: () => _toggleSelection(conversation),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              key: const Key('startChat'),
              onPressed: () => context.push(AppRoutes.newConversation),
              icon: const Icon(Icons.chat_bubble_outline, size: 22),
              label: const Text('Démarrer une discussion'),
            ),
    );
  }

  Future<void> _open(ConversationDto conversation) async {
    if (_selecting) {
      _toggleSelection(conversation);
      return;
    }
    await context.push(AppRoutes.thread(conversation.threadId));
    // Au retour du fil : le brouillon a pu changer, les messages être lus. Les
    // événements du stock ne couvrent pas ces états, propres à l'app.
    if (mounted) ref.invalidate(conversationsProvider);
  }

  void _toggleSelection(ConversationDto conversation) {
    setState(() {
      if (!_selection.remove(conversation.threadId)) {
        _selection.add(conversation.threadId);
      }
    });
  }

  PreferredSizeWidget _selectionAppBar(BuildContext context) {
    final selected = _selection.toList();
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selection.clear),
      ),
      title: Text('${_selection.length}'),
      actions: [
        IconButton(
          key: const Key('selectionPin'),
          tooltip: 'Épingler',
          icon: const Icon(Icons.push_pin_outlined),
          onPressed: () => _apply(
            selected,
            (id) => ref
                .read(updateConversationFlagsUseCaseProvider)
                .togglePinned(id),
          ),
        ),
        IconButton(
          key: const Key('selectionArchive'),
          tooltip: 'Archiver',
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => _apply(
            selected,
            (id) => ref
                .read(updateConversationFlagsUseCaseProvider)
                .toggleArchived(id),
          ),
        ),
        IconButton(
          key: const Key('selectionMute'),
          tooltip: 'Sourdine',
          icon: const Icon(Icons.notifications_off_outlined),
          onPressed: () => _apply(
            selected,
            (id) =>
                ref.read(updateConversationFlagsUseCaseProvider).toggleMuted(id),
          ),
        ),
        IconButton(
          key: const Key('selectionMarkRead'),
          tooltip: 'Marquer comme lu',
          icon: const Icon(Icons.mark_email_read_outlined),
          onPressed: () => _apply(
            selected,
            (id) => ref.read(markConversationReadUseCaseProvider).execute(id),
          ),
        ),
        IconButton(
          key: const Key('selectionDelete'),
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(selected),
        ),
      ],
    );
  }

  Future<void> _apply(
    List<String> threadIds,
    Future<void> Function(String) action,
  ) async {
    for (final threadId in threadIds) {
      await action(threadId);
    }
    if (!mounted) return;
    setState(_selection.clear);
    ref.invalidate(conversationsProvider);
  }

  Future<void> _confirmDelete(List<String> threadIds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          threadIds.length == 1
              ? 'Supprimer cette conversation ?'
              : 'Supprimer ${threadIds.length} conversations ?',
        ),
        content: const Text(
          'Les messages seront définitivement supprimés de cet appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            key: const Key('confirmDelete'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _apply(
      threadIds,
      (id) => ref.read(deleteConversationUseCaseProvider).execute(id),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // La liste doit rester tirable pour rafraîchir, même vide.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 64,
          color: colors.textMuted.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 20),
        Text(
          'Aucune conversation',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Appuyez sur « Démarrer une discussion » pour envoyer votre premier '
          'message.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Icon(Icons.error_outline, size: 56, color: colors.danger),
        const SizedBox(height: 16),
        Text(
          'Impossible de lire vos messages',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          error,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
      ],
    );
  }
}
