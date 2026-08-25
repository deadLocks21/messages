import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// La barre flottante en tête de la liste : recherche à gauche, menu du compte
/// à droite. C'est le seul « app bar » de l'écran d'accueil de Google Messages.
class MessagesSearchBar extends StatelessWidget {
  const MessagesSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('openSearch'),
          onTap: () => context.push(AppRoutes.search),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search, color: colors.textMuted, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rechercher dans les conversations',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 15),
                  ),
                ),
                const _AccountMenu(),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de compte : donne accès aux archives et aux paramètres, là où
/// Google Messages loge le menu du compte Google.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopupMenuButton<String>(
      key: const Key('accountMenu'),
      tooltip: 'Compte',
      position: PopupMenuPosition.under,
      onSelected: (value) => switch (value) {
        'archived' => context.push(AppRoutes.archived),
        'settings' => context.push(AppRoutes.settings),
        _ => null,
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'archived',
          child: ListTile(
            leading: Icon(Icons.archive_outlined),
            title: Text('Archivées'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Paramètres'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: colors.accentSoft,
        child: Icon(Icons.person, size: 18, color: colors.onAccentSoft),
      ),
    );
  }
}
