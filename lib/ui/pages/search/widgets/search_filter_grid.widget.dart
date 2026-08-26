import 'package:flutter/material.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Les raccourcis de tri proposés par l'écran de recherche tant que rien n'est
/// tapé : deux colonnes de cartes très arrondies, comme dans Google Messages.
///
/// L'app d'origine en propose huit, dont la moitié porte sur des contenus que
/// ce client ne gère pas (images, vidéos, lieux, liens — tout cela est du MMS
/// ou du RCS). Ne restent que les filtres réellement branchés sur le stock.
class SearchFilterGrid extends StatelessWidget {
  const SearchFilterGrid({super.key, required this.onSelected});

  final ValueChanged<ConversationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 3.4,
      shrinkWrap: true,
      children: [
        _FilterCard(
          key: const Key('filterUnread'),
          icon: Icons.mark_chat_unread_outlined,
          label: 'Non lues',
          onTap: () => onSelected(ConversationFilter.unread),
        ),
        _FilterCard(
          key: const Key('filterArchived'),
          icon: Icons.archive_outlined,
          label: 'Archivées',
          onTap: () => onSelected(ConversationFilter.archived),
        ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(icon, size: 24, color: colors.accent),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary, fontSize: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
