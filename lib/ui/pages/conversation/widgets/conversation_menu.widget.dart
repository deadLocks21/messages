import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';

/// Menu « ⋮ » d'un fil : ses détails, puis épingler, archiver, mettre en
/// sourdine, supprimer.
///
/// « Détails » ouvre le même écran que l'appui sur le nom, et se tient en tête
/// du menu comme dans l'app d'origine : le menu est le second chemin vers lui,
/// pour qui ne devine pas que le nom est un bouton.
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
        const PopupMenuItem(
          value: 'details',
          height: 56,
          child: Text('Détails'),
        ),
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
            conversation.isSilenced
                ? 'Réactiver les notifications'
                : 'Sourdine',
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
      case 'details':
        context.push(AppRoutes.threadDetails(conversation.threadId));
        return;
      case 'pin':
        await flags.togglePinned(conversation.threadId);
      case 'archive':
        await flags.toggleArchived(conversation.threadId);
      case 'mute':
        // `wake` plutôt qu'un basculement : un fil mis en veille jusqu'à 18 h
        // n'est pas « en sourdine », et pourtant le menu propose bien de le
        // réveiller. Les deux états sortent par la même porte.
        await (conversation.isSilenced
            ? flags.wake(conversation.threadId)
            : flags.toggleMuted(conversation.threadId));
      case 'delete':
        if (!context.mounted) return;
        final confirmed = await confirmDelete(context);
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

  /// Exposée : l'écran de détails supprime le même fil, et la question doit
  /// être posée dans les mêmes mots des deux endroits.
  static Future<bool?> confirmDelete(BuildContext context) => showDialog<bool>(
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
