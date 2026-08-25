import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/infrastructure/providers/theme_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Paramètres : thème, statut d'application SMS par défaut, autorisations.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final themeMode = ref.watch(themeModeControllerProvider).value;
    final access = ref.watch(smsAccessControllerProvider).value;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const _SectionHeader('Apparence'),
          // `RadioGroup` porte la valeur et le callback ; les tuiles ne
          // déclarent plus que leur propre valeur (API Material 3).
          RadioGroup<AppThemeMode>(
            groupValue: themeMode,
            onChanged: (value) => value == null
                ? null
                : ref.read(themeModeControllerProvider.notifier).set(value),
            child: Column(
              children: AppThemeMode.values
                  .map(
                    (mode) => RadioListTile<AppThemeMode>(
                      key: Key('themeMode_${mode.name}'),
                      value: mode,
                      title: Text(switch (mode) {
                        AppThemeMode.light => 'Clair',
                        AppThemeMode.dark => 'Sombre',
                        AppThemeMode.system => 'Thème de l\'appareil',
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(),
          const _SectionHeader('SMS'),
          ListTile(
            key: const Key('defaultAppTile'),
            leading: Icon(
              access?.isDefaultSmsApp == true
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: access?.isDefaultSmsApp == true
                  ? colors.accent
                  : colors.danger,
            ),
            title: const Text('Application SMS par défaut'),
            subtitle: Text(
              access?.isDefaultSmsApp == true
                  ? 'Messages est votre application SMS.'
                  : 'Requis pour envoyer et recevoir des messages.',
            ),
            trailing: access?.isDefaultSmsApp == true
                ? null
                : TextButton(
                    onPressed: () => ref
                        .read(smsAccessControllerProvider.notifier)
                        .requestDefaultSmsApp(),
                    child: const Text('Définir'),
                  ),
          ),
          ListTile(
            key: const Key('permissionsTile'),
            leading: Icon(
              access?.canReadSms == true
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: access?.canReadSms == true ? colors.accent : colors.danger,
            ),
            title: const Text('Autorisations'),
            subtitle: Text(
              _permissionsLabel(access?.canReadSms, access?.canReadContacts),
            ),
            trailing: access?.canReadSms == true && access?.canReadContacts == true
                ? null
                : TextButton(
                    onPressed: () => ref
                        .read(smsAccessControllerProvider.notifier)
                        .requestPermissions(),
                    child: const Text('Accorder'),
                  ),
          ),
          const Divider(),
          const _SectionHeader('À propos'),
          const ListTile(
            title: Text('Messages'),
            subtitle: Text(
              'Client SMS écrit en Flutter, architecture hexagonale.',
            ),
          ),
        ],
      ),
    );
  }

  String _permissionsLabel(bool? sms, bool? contacts) {
    if (sms != true) return 'L\'accès aux SMS est refusé.';
    if (contacts != true) {
      return 'SMS accordés. Sans les contacts, les fils affichent les numéros.';
    }
    return 'SMS et contacts accordés.';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
