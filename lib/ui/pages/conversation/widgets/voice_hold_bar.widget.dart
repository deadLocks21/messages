import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';
import 'package:messages/ui/providers/voice_recorder.provider.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Ce que devient le champ de rédaction tant que le doigt tient le disque :
/// `● 00:03 🗑 ‹ Faire glisser pour annuler`.
///
/// Elle prend très exactement la place de la pilule — même hauteur, mêmes
/// coins, même fond — parce que c'est la même barre qui change de rôle, pas
/// une barre qui vient s'ajouter. Rien ne doit sauter au moment où le micro
/// s'ouvre.
///
/// Elle lit le compteur **elle-même** plutôt que de le recevoir de la page :
/// le micro publie un relevé toutes les 100 ms, et faire remonter cela jusqu'à
/// `ConversationPage` repeindrait le fil dix fois par seconde pour deux
/// chiffres qui changent une fois sur dix.
class VoiceHoldBar extends ConsumerWidget {
  const VoiceHoldBar({super.key, required this.cancelProgress});

  /// À quelle distance de la corbeille est le doigt, de 0 (au départ) à 1 (à
  /// l'instant où ça annule). La barre s'efface à mesure, et la corbeille
  /// rougit : le geste doit dire ce qu'il va faire **avant** de le faire.
  final double cancelProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final recording =
        ref.watch(voiceRecordingProvider).value ?? VoiceRecording.idle;

    return Opacity(
      // Jamais jusqu'à zéro : une barre disparue laisserait croire que c'est
      // déjà annulé, alors que le doigt peut encore revenir.
      opacity: 1 - 0.55 * cancelProgress,
      child: Container(
        key: const Key('voiceHoldBar'),
        height: MessageComposer.pillHeight,
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.only(left: 20, right: 16),
        child: Row(
          children: [
            // La pastille rouge, et elle seule, dit que le micro est ouvert —
            // même règle que dans le panneau : un compteur qui avance pourrait
            // tout aussi bien être une lecture.
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AttachmentDto.formatDuration(recording.elapsed),
              key: const Key('voiceHoldElapsed'),
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
                // Chiffres de largeur fixe : sans cela le compteur se
                // dandinerait à chaque seconde, et toute la ligne avec lui.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.delete_outline,
              size: 22,
              // Elle rougit sous le doigt qui s'en approche : c'est elle qui
              // dit où mène le glissé, le texte ne fait que le nommer.
              color: Color.lerp(
                colors.textPrimary,
                colors.danger,
                cancelProgress,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_left, size: 20, color: colors.textMuted),
            Expanded(
              child: Text(
                'Faire glisser pour annuler',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La pastille blanche au-dessus du disque : un cadenas, un chevron, et ce
/// qu'ils promettent — l'enregistrement peut continuer sans le doigt.
///
/// Relevée sur l'appareil : 42 × 68 dp, centrée sur le disque, 24 dp au-dessus
/// de lui.
class VoiceLockChip extends StatelessWidget {
  const VoiceLockChip({super.key, required this.progress});

  /// À quelle distance du verrouillage est le doigt, de 0 à 1. Le cadenas se
  /// ferme à l'approche — il montre ce qui va se passer plutôt que ce qui est.
  final double progress;

  static const width = 42.0;
  static const height = 68.0;

  /// Écart entre le bas de la pastille et le haut du disque **gonflé**. Les
  /// 24 dp du relevé, plus les 4 dp dont le disque déborde de sa boîte.
  static const gap = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final closing = progress > 0.5;

    return Container(
      key: const Key('voiceLockChip'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(width / 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(
            closing ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 20,
            color: closing ? colors.accent : colors.textPrimary,
            semanticLabel: 'Verrouiller l\'enregistrement',
          ),
          Icon(Icons.keyboard_arrow_up, size: 20, color: colors.textMuted),
        ],
      ),
    );
  }
}
