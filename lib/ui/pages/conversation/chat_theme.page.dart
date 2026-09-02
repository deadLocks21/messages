import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/theme/chat_theme.widget.dart';

/// « Thème de discussion » : une couleur pour ce fil, une photo derrière, ou
/// le thème de l'appareil.
///
/// L'aperçu du haut est le sujet de l'écran, pas une décoration : c'est le
/// seul endroit où l'on voit ce qu'une graine donne avant de la choisir. Il
/// est rethémé en direct par [ChatTheme], exactement comme le fil le sera.
///
/// Ce que l'app d'origine a en plus : un **catalogue** de fonds d'écran
/// (animaux, architecture, noir et blanc…). Ce sont ses images ; il n'y a rien
/// à reproduire, seulement à ne pas prétendre.
class ChatThemePage extends ConsumerWidget {
  const ChatThemePage({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final conversation = ref.watch(conversationProvider(threadId)).value;
    final seed = conversation?.themeSeed;
    final themed = seed != null || conversation?.wallpaperPath != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('Thème de discussion'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ChatTheme(
              seed: seed,
              child: _Preview(wallpaper: conversation?.wallpaperPath),
            ),
          ),
          if (themed)
            Center(
              child: TextButton.icon(
                key: const Key('resetChatTheme'),
                onPressed: () => _reset(ref),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Rétablir le thème de l\'appareil'),
              ),
            ),
          const _SectionTitle('Couleurs'),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: ChatTheme.seeds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final value = ChatTheme.seeds[index];
                return _Swatch(
                  seed: value,
                  selected: seed == value,
                  onTap: () => ref
                      .read(updateChatThemeUseCaseProvider)
                      .setSeed(threadId, value)
                      .then((_) => _refresh(ref)),
                );
              },
            ),
          ),
          const _SectionTitle('Fond d\'écran'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              key: const Key('pickWallpaper'),
              onPressed: () => _pickWallpaper(context, ref),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir une photo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWallpaper(BuildContext context, WidgetRef ref) async {
    final picked = await ref
        .read(attachmentPickerProvider)
        .pick(AttachmentSource.gallery);
    // Une sélection annulée rend une liste vide : ce n'est pas une erreur.
    if (picked.isEmpty) return;

    final path = await ref
        .read(wallpaperRepositoryProvider)
        .save(threadId: threadId, uri: picked.first.uri);
    if (!context.mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette image n\'a pas pu être lue.')),
      );
      return;
    }
    await ref.read(updateChatThemeUseCaseProvider).setWallpaper(threadId, path);
    _refresh(ref);
  }

  Future<void> _reset(WidgetRef ref) async {
    await ref.read(updateChatThemeUseCaseProvider).reset(threadId);
    _refresh(ref);
  }

  /// Le fil et sa ligne dans la liste changent de couleur : les deux vues
  /// lisent la même préférence, et aucune ne s'en aperçoit toute seule.
  void _refresh(WidgetRef ref) {
    ref.invalidate(conversationProvider(threadId));
    ref.invalidate(conversationDetailsProvider(threadId));
    ref.invalidate(conversationsProvider);
  }
}

/// Le fil, en miniature. Les phrases sont muettes exprès : ce qu'on regarde,
/// c'est la couleur des bulles, pas ce qu'elles disent.
class _Preview extends StatelessWidget {
  const _Preview({this.wallpaper});

  final String? wallpaper;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final photo = wallpaper;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Le fond d'écran est du sujet, pas du décor : le choisir sans le
          // voir reviendrait à l'essayer dans le fil.
          if (photo != null)
            Positioned.fill(
              child: Image.file(
                File(photo),
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => const SizedBox.shrink(),
              ),
            ),
          Container(
            color: photo == null
                ? colors.surface
                : colors.surface.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Bubble(
                  text: 'Je t\'appelle ce soir',
                  outgoing: true,
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _Bubble(text: 'Très bien, à tout à l\'heure', colors: colors),
                const SizedBox(height: 8),
                _Bubble(text: 'On se voit où ?', colors: colors),
                const SizedBox(height: 16),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Message texte',
                    style: TextStyle(color: colors.textMuted, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.colors,
    this.outgoing = false,
  });

  final String text;
  final AppColors colors;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: outgoing ? colors.bubbleOutgoing : colors.bubbleIncoming,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: outgoing ? colors.onBubbleOutgoing : colors.onBubbleIncoming,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// Une pastille de couleur : ce qu'une graine donne, en trois tons.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final int seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ChatTheme(
      seed: seed,
      child: Builder(
        builder: (context) {
          final themed = context.appColors;
          return InkResponse(
            key: Key('chatThemeSeed_$seed'),
            onTap: onTap,
            radius: 40,
            // `Center` : la rangée impose sa hauteur, et sans lui la pastille
            // s'étirait en ovale.
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colors.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                // `stretch` des deux côtés : un `ColoredBox` sans enfant prend
                // la *plus petite* taille que ses contraintes permettent, et
                // dans une `Column` lâche en largeur, cela vaut zéro — la
                // pastille s'affichait vide.
                child: ClipOval(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ColoredBox(color: themed.accent)),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ColoredBox(color: themed.bubbleOutgoing),
                            ),
                            Expanded(child: ColoredBox(color: themed.voice)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
    child: Text(
      label,
      style: TextStyle(color: context.appColors.textPrimary, fontSize: 18),
    ),
  );
}
