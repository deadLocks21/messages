import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/providers/conversation_providers.dart';

/// Menu « ⋮ » d'un fil : épingler, archiver, mettre en sourdine, supprimer.
class ConversationMenu extends ConsumerWidget {
  const ConversationMenu({
    super.key,
    required this.conversation,
    required this.onDeleted,
  });

  final ConversationDto conversation;

  /// Appelé après une suppression : l'écran du fil n'a plus lieu d'être.
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Entrées hautes et espacées : le menu « ⋮ » de l'app d'origine respire
    // beaucoup plus que le PopupMenuItem par défaut.
    return PopupMenuButton<String>(
      key: const Key('conversationMenu'),
      position: PopupMenuPosition.under,
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          height: 56,
          child: Text(conversation.isPinned ? 'Ne plus épingler' : 'Épingler'),
        ),
        PopupMenuItem(
          value: 'archive',
          height: 56,
          child: Text(conversation.isArchived ? 'Désarchiver' : 'Archiver'),
        ),
        PopupMenuItem(
          value: 'mute',
          height: 56,
          child: Text(
            conversation.isMuted ? 'Réactiver les notifications' : 'Sourdine',
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          height: 56,
          child: Text('Supprimer'),
        ),
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final flags = ref.read(updateConversationFlagsUseCaseProvider);
    switch (value) {
      case 'pin':
        await flags.togglePinned(conversation.threadId);
      case 'archive':
        await flags.toggleArchived(conversation.threadId);
      case 'mute':
        await flags.toggleMuted(conversation.threadId);
      case 'delete':
        if (!context.mounted) return;
        final confirmed = await _confirmDelete(context);
        if (confirmed != true) return;
        await ref
            .read(deleteConversationUseCaseProvider)
            .execute(conversation.threadId);
        ref.invalidate(conversationsProvider);
        onDeleted();
        return;
    }
    ref.invalidate(conversationProvider(conversation.threadId));
    ref.invalidate(conversationsProvider);
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer cette conversation ?'),
      content: const Text(
        'Les messages seront définitivement supprimés de cet appareil.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          key: const Key('confirmDeleteThread'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}
