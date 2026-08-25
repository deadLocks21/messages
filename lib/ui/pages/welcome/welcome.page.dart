import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Écran d'accueil, affiché tant que l'app ne peut pas lire les SMS.
///
/// Deux étapes distinctes, dans l'ordre où Android les impose : les
/// autorisations, puis le rôle d'application SMS par défaut.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final access = ref.watch(smsAccessControllerProvider).value ?? SmsAccess.none;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.chat_bubble_outline, size: 72, color: colors.accent),
              const SizedBox(height: 28),
              Text(
                'Bienvenue dans Messages',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Messages a besoin d\'accéder à vos SMS et à vos contacts pour '
                'afficher vos conversations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 32),
              _Step(
                index: 1,
                label: 'Autoriser l\'accès aux SMS et aux contacts',
                done: access.canReadSms,
              ),
              const SizedBox(height: 12),
              _Step(
                index: 2,
                label: 'Définir Messages comme application SMS par défaut',
                done: access.isDefaultSmsApp,
              ),
              const SizedBox(height: 32),
              if (!access.canReadSms)
                FilledButton(
                  key: const Key('grantPermissions'),
                  onPressed: () => ref
                      .read(smsAccessControllerProvider.notifier)
                      .requestPermissions(),
                  child: const Text('Autoriser'),
                )
              else
                FilledButton(
                  key: const Key('grantDefaultApp'),
                  onPressed: () => ref
                      .read(smsAccessControllerProvider.notifier)
                      .requestDefaultSmsApp(),
                  child: const Text('Définir comme application par défaut'),
                ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('refreshAccess'),
                onPressed: () =>
                    ref.read(smsAccessControllerProvider.notifier).refresh(),
                child: const Text('J\'ai déjà accordé l\'accès'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.label, required this.done});

  final int index;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: done ? colors.accent : colors.surfaceAlt,
          child: done
              ? Icon(Icons.check, size: 16, color: colors.onAccent)
              : Text(
                  '$index',
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done ? colors.textMuted : colors.textPrimary,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}
