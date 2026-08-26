import 'package:flutter/material.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// La pilule de recherche de Google Messages : flèche de retour et saisie dans
/// un même bloc arrondi, posé sur le fond pêche.
///
/// Quand un filtre est actif, il s'affiche en puce à l'intérieur de la pilule,
/// juste avant le champ — l'app d'origine fait de même.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClearQuery,
    required this.onBack,
    this.filterLabel,
    this.onClearFilter,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearQuery;
  final VoidCallback onBack;

  /// Libellé du filtre actif, s'il y en a un.
  final String? filterLabel;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Row(
            children: [
              IconButton(
                key: const Key('closeSearch'),
                tooltip: 'Retour',
                icon: const Icon(Icons.arrow_back),
                color: colors.textPrimary,
                onPressed: onBack,
              ),
              if (filterLabel != null) ...[
                _FilterPill(label: filterLabel!, onClear: onClearFilter),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  key: const Key('searchField'),
                  controller: controller,
                  autofocus: true,
                  onChanged: onChanged,
                  style: TextStyle(color: colors.textPrimary, fontSize: 17),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Rechercher des messages',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 17),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  key: const Key('clearSearch'),
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.close),
                  color: colors.textPrimary,
                  onPressed: onClearQuery,
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, this.onClear});

  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: const Key('activeFilterPill'),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.onAccentSoft,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          InkResponse(
            onTap: onClear,
            radius: 16,
            child: Icon(Icons.close, size: 18, color: colors.onAccentSoft),
          ),
        ],
      ),
    );
  }
}
