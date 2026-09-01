import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/providers/reaction_providers.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/infrastructure/providers/theme_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/card_group.widget.dart';

/// Paramètres : thème, statut d'application SMS par défaut, autorisations.
///
/// Cartes arrondies posées sur le fond pêche, comme les réglages de l'app
/// d'origine.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final themeMode = ref.watch(themeModeControllerProvider).value;
    final access = ref.watch(smsAccessControllerProvider).value;
    final foldsReactions =
        ref.watch(reactionFoldingControllerProvider).value ?? true;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(toolbarHeight: 64, title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const CardGroupHeader('Apparence'),
          // `RadioGroup` porte la valeur et le callback ; les tuiles ne
          // déclarent plus que leur propre valeur (API Material 3).
          RadioGroup<AppThemeMode>(
            groupValue: themeMode,
            onChanged: (value) => value == null
                ? null
                : ref.read(themeModeControllerProvider.notifier).set(value),
            child: CardGroup(
              children: AppThemeMode.values
                  .map(
                    (mode) => RadioListTile<AppThemeMode>(
                      key: Key('themeMode_${mode.name}'),
                      value: mode,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
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
          const CardGroupHeader('Messages'),
          CardGroup(
            children: [
              CardRow(
                key: const Key('foldReactionsTile'),
                icon: Icons.add_reaction_outlined,
                iconColor: colors.accent,
                label: 'Afficher les réactions comme des emoji',
                // Dire ce qu'on verra si on coupe, plutôt que ce qu'on perd :
                // c'est la phrase brute qui explique tout le reste — pourquoi
                // il y a un réglage, et ce qui circule vraiment sur le réseau.
                subtitle: foldsReactions
                    ? 'Les réactions se posent sur la bulle qu\'elles visent.'
                    : 'Affichées telles qu\'elles circulent : « Liked “…” ».',
                trailing: Switch(
                  key: const Key('foldReactionsSwitch'),
                  value: foldsReactions,
                  onChanged: (value) => ref
                      .read(reactionFoldingControllerProvider.notifier)
                      .set(value),
                ),
              ),
            ],
          ),
          const CardGroupHeader('SMS'),
          CardGroup(
            children: [
              CardRow(
                key: const Key('defaultAppTile'),
                icon: access?.isDefaultSmsApp == true
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                iconColor: access?.isDefaultSmsApp == true
                    ? colors.accent
                    : colors.danger,
                label: 'Application SMS par défaut',
                subtitle: access?.isDefaultSmsApp == true
                    ? 'Messages est votre application SMS.'
                    : 'Requis pour envoyer et recevoir des messages.',
                trailing: access?.isDefaultSmsApp == true
                    ? null
                    : TextButton(
                        onPressed: () => ref
                            .read(smsAccessControllerProvider.notifier)
                            .requestDefaultSmsApp(),
                        child: const Text('Définir'),
                      ),
              ),
              CardRow(
                key: const Key('notificationsTile'),
                icon: access?.canNotify == true
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                iconColor: access?.canNotify == true
                    ? colors.accent
                    : colors.danger,
                label: 'Notifications',
                subtitle: access?.canNotify == true
                    ? 'Vous êtes averti des nouveaux messages.'
                    : 'Désactivées : aucun message reçu ne sera signalé.',
                trailing: access?.canNotify == true
                    ? null
                    : TextButton(
                        key: const Key('enableNotifications'),
                        onPressed: () => _enableNotifications(ref),
                        child: const Text('Activer'),
                      ),
              ),
              CardRow(
                key: const Key('permissionsTile'),
                icon: access?.canReadSms == true
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                iconColor: access?.canReadSms == true
                    ? colors.accent
                    : colors.danger,
                label: 'Autorisations',
                subtitle: _permissionsLabel(
                  access?.canReadSms,
                  access?.canReadContacts,
                ),
                trailing:
                    access?.canReadSms == true &&
                        access?.canReadContacts == true
                    ? null
                    : TextButton(
                        onPressed: () => ref
                            .read(smsAccessControllerProvider.notifier)
                            .requestPermissions(),
                        child: const Text('Accorder'),
                      ),
              ),
            ],
          ),
          const CardGroupHeader('À propos'),
          const CardGroup(
            children: [
              CardRow(
                label: 'Messages',
                subtitle:
                    'Client SMS écrit en Flutter, architecture hexagonale.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Une permission refusée définitivement ne redemande plus rien : au bout du
  /// deuxième refus, Android n'affiche plus la boîte de dialogue et le seul
  /// recours est la fiche de l'app dans les réglages.
  Future<void> _enableNotifications(WidgetRef ref) async {
    final controller = ref.read(smsAccessControllerProvider.notifier);
    final access = await controller.requestPermissions();
    if (access.canNotify) return;
    await controller.openSystemSettings();
  }

  String _permissionsLabel(bool? sms, bool? contacts) {
    if (sms != true) return 'L\'accès aux SMS est refusé.';
    if (contacts != true) {
      return 'SMS accordés. Sans les contacts, les fils affichent les numéros.';
    }
    return 'SMS et contacts accordés.';
  }
}
