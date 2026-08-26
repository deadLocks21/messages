import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/card_group.widget.dart';

/// La feuille du compte, ouverte par la pastille en haut à droite.
///
/// Reprend la forme de celle de Google Messages — pastille, salutation, puis
/// des cartes d'accès — sans le compte Google lui-même : l'app est un client
/// SMS local, il n'y a pas de session à afficher.
abstract final class AccountSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) => const _AccountSheetBody(),
    );
  }
}

class _AccountSheetBody extends StatelessWidget {
  const _AccountSheetBody();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('closeAccountSheet'),
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.chat_bubble_outline,
                size: 42,
                color: colors.onAccentSoft,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Vos messages, sur cet appareil',
              style: TextStyle(color: colors.textPrimary, fontSize: 22),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Rien n\'est envoyé à un serveur : les SMS restent dans le '
                'stock du téléphone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, fontSize: 14),
              ),
            ),
            const CardGroupHeader('Plus de contenus de cette appli'),
            CardGroup(
              children: [
                CardRow(
                  key: const Key('accountArchived'),
                  icon: Icons.archive_outlined,
                  label: 'Messages archivés',
                  onTap: () => _go(context, AppRoutes.archived),
                ),
                CardRow(
                  key: const Key('accountSettings'),
                  icon: Icons.settings_outlined,
                  label: 'Paramètres de l\'application Messages',
                  onTap: () => _go(context, AppRoutes.settings),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// La feuille se referme avant de naviguer : sinon elle resterait au-dessus
  /// de l'écran ouvert.
  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }
}
