import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Bandeau affiché tant que l'app n'est pas celle par défaut : elle peut lire
/// le stock, mais Android lui refuse toute écriture — donc tout envoi.
class DefaultAppBanner extends ConsumerWidget {
  const DefaultAppBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Container(
      key: const Key('defaultAppBanner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.onAccentSoft, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Définissez Messages comme application SMS par défaut pour '
              'envoyer des messages.',
              style: TextStyle(color: colors.onAccentSoft, fontSize: 13),
            ),
          ),
          TextButton(
            key: const Key('setDefaultApp'),
            onPressed: () => ref
                .read(smsAccessControllerProvider.notifier)
                .requestDefaultSmsApp(),
            style: TextButton.styleFrom(foregroundColor: colors.onAccentSoft),
            child: const Text('Définir'),
          ),
        ],
      ),
    );
  }
}
