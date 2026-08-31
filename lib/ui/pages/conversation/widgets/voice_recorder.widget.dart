import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/voice_recording.dart';
import 'package:messages/core/domain/model/waveform.dart';
import 'package:messages/ui/pages/conversation/widgets/audio_attachment.widget.dart';
import 'package:messages/ui/providers/voice_recorder.provider.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Le panneau d'enregistrement d'un vocal, sous le champ de rédaction.
///
/// Trois états, et les mêmes trois boutons en dessous — c'est la mise en page
/// de l'app d'origine, relevée à l'émulateur :
///
/// | | Panneau | Gauche | Milieu | Droite |
/// |---|---|---|---|---|
/// | **Au repos** | « Appuyez pour enregistrer » | Annuler | micro | Joindre *(éteint)* |
/// | **Enregistrement** | compteur, piste, suppression du bruit | Recommencer | stop *(rouge)* | Joindre |
/// | **Enregistré** | le lecteur du vocal | Recommencer | micro *(éteint)* | Joindre |
///
/// « Joindre » est vif dès qu'il y a quelque chose à joindre — pendant
/// l'enregistrement compris : l'app d'origine ne demande pas d'appuyer sur
/// « stop » d'abord, et il n'y a aucune raison d'exiger deux gestes là où le
/// premier dit déjà tout.
///
/// Le bouton de gauche est le seul à changer de nom : « Annuler » referme le
/// panneau, « Recommencer » le garde ouvert. Les deux jettent ce qui est en
/// cours — une seule règle, dans les deux états où le bouton existe.
///
/// Le panneau ne tient pas le micro : il reconnaît l'état que publie
/// `AudioRecorderService`, exactement comme une bulle reconnaît la lecture en
/// cours dans l'état publié par le lecteur.
class VoiceRecorderPanel extends ConsumerWidget {
  const VoiceRecorderPanel({
    super.key,
    required this.threadId,
    required this.onError,
  });

  final String threadId;

  /// Ce qu'on ne peut dire qu'ici : un micro refusé, un enregistrement qui ne
  /// démarre pas. La page sait l'afficher ; le panneau, non.
  final ValueChanged<Object> onError;

  /// Relevé sur l'émulateur (420 dpi) : panneau de 202 dp, marges de 8 dp,
  /// coins de 24 dp, et 8 dp entre le panneau et sa rangée de boutons.
  static const panelHeight = 202.0;
  static const panelRadius = 24.0;
  static const margin = 8.0;
  static const buttonHeight = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(voiceRecorderProvider(threadId));
    // Pendant l'appui maintenu, c'est le champ de rédaction qui porte
    // l'enregistrement : deux surfaces pour le même micro se contrediraient.
    if (!panel.isPanel) return const SizedBox.shrink();

    final colors = context.appColors;
    final recording =
        ref.watch(voiceRecordingProvider).value ?? VoiceRecording.idle;
    final recorded = panel.recorded;
    final controller = ref.read(voiceRecorderProvider(threadId).notifier);

    return Padding(
      key: const Key('voiceRecorderPanel'),
      // 6 en haut, contre les 10 du bas du champ : les 16 dp de l'app
      // d'origine entre la pilule et le panneau.
      padding: const EdgeInsets.fromLTRB(margin, 6, margin, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: panelHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(panelRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: switch ((recording.isRecording, recorded)) {
              (true, _) => _Recording(recording: recording),
              (false, final AttachmentDraftDto draft) => _Recorded(
                draft: draft,
              ),
              _ => const _Invitation(),
            },
          ),
          const SizedBox(height: margin),
          _Actions(
            recording: recording,
            hasRecording: recorded != null,
            onLeft: recording.isRecording || recorded != null
                ? controller.restart
                : controller.close,
            onRecord: () async {
              try {
                await controller.record();
              } catch (e) {
                onError(e);
              }
            },
            onStop: controller.stop,
            onAttach: switch ((recording.isRecording, recorded)) {
              // En cours : joindre, c'est arrêter puis joindre.
              (true, _) => controller.stopAndAttach,
              (false, null) => null,
              _ => controller.attach,
            },
          ),
        ],
      ),
    );
  }
}

/// L'état d'ouverture : rien n'a encore été dit.
///
/// L'app d'origine y met une illustration ; on s'en tient au geste à faire.
/// Une illustration qui n'existe pas dans l'app se dessinerait mal et
/// vieillirait seule.
class _Invitation extends StatelessWidget {
  const _Invitation();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.graphic_eq, size: 40, color: colors.onPanel),
          const SizedBox(height: 16),
          Text(
            'Appuyez pour enregistrer votre voix',
            key: const Key('voiceInvitation'),
            style: TextStyle(fontSize: 15, color: colors.onPanel),
          ),
        ],
      ),
    );
  }
}

/// L'enregistrement en cours : le compteur, la piste, et ce que l'appareil
/// fait du bruit de fond.
class _Recording extends StatelessWidget {
  const _Recording({required this.recording});

  final VoiceRecording recording;

  /// Hauteur réservée à la pastille de suppression du bruit, qu'elle soit là
  /// ou non.
  static const chipHeight = 38.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // La pastille rouge, et elle seule, dit que le micro est ouvert :
            // un compteur qui avance pourrait tout aussi bien être une lecture.
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AttachmentDto.formatDuration(recording.elapsed),
              key: const Key('voiceElapsed'),
              style: TextStyle(
                fontSize: 32,
                color: colors.onPanel,
                // Chiffres de largeur fixe : sans cela le compteur se
                // dandinerait à chaque seconde.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        // La piste se centre dans ce qui reste entre le compteur et la
        // pastille : sans cela, un appareil qui ne sait pas traiter le bruit —
        // et n'affiche donc pas la pastille — la laisserait tomber au fond du
        // panneau.
        Expanded(
          child: Center(
            child: SizedBox(
              height: 40,
              width: double.infinity,
              child: CustomPaint(
                key: const Key('voiceLevels'),
                painter: VoiceLevelsPainter(
                  waveform: recording.waveform,
                  color: colors.onPanel,
                ),
              ),
            ),
          ),
        ),
        // Annoncée seulement là où elle existe : promettre une suppression du
        // bruit que l'appareil n'a pas ferait parler plus fort pour rien. Sa
        // place, elle, est toujours réservée — sans quoi la piste remonterait
        // ou descendrait selon l'appareil, pour une raison invisible.
        SizedBox(
          height: chipHeight,
          child: recording.noiseSuppression ? const _NoiseChip() : null,
        ),
      ],
    );
  }
}

/// « Suppression du bruit **Activée** » : ce que le système fait du bruit de
/// fond pendant qu'on parle.
class _NoiseChip extends StatelessWidget {
  const _NoiseChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.noise_control_off, size: 18, color: colors.onPanel),
            const SizedBox(width: 8),
            Text.rich(
              const TextSpan(
                text: 'Suppression du bruit ',
                children: [
                  TextSpan(
                    text: 'Activée',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 14, color: colors.onPanel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ce qui vient d'être dit, à réécouter avant de le joindre.
///
/// Le même lecteur que dans une bulle, et pas un aperçu à part : un vocal
/// s'écoute d'une seule façon, avant comme après l'envoi. Le port de lecture
/// ouvre un brouillon comme il ouvre une partie du stock.
class _Recorded extends StatelessWidget {
  const _Recorded({required this.draft});

  final AttachmentDraftDto draft;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) => AudioAttachment(
          key: const Key('voicePreview'),
          attachment: AttachmentDto.fromDraft(draft),
          foreground: colors.onPanel,
          background: colors.panel,
          maxWidth: constraints.maxWidth,
        ),
      ),
    );
  }
}

/// La rangée de trois boutons sous le panneau : trois parts égales, séparées
/// de 8 dp — le relevé de l'app d'origine.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.recording,
    required this.hasRecording,
    required this.onLeft,
    required this.onRecord,
    required this.onStop,
    required this.onAttach,
  });

  final VoiceRecording recording;
  final bool hasRecording;
  final VoidCallback onLeft;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isRecording = recording.isRecording;

    return Row(
      children: [
        Expanded(
          child: _PillButton(
            key: const Key('voiceLeftAction'),
            // Le libellé dit ce qu'il advient du panneau, pas de
            // l'enregistrement : les deux le jettent.
            label: isRecording || hasRecording ? 'Recommencer' : 'Annuler',
            icon: isRecording || hasRecording ? Icons.refresh : Icons.close,
            background: colors.surfaceAlt,
            foreground: colors.accent,
            onPressed: onLeft,
          ),
        ),
        const SizedBox(width: VoiceRecorderPanel.margin),
        Expanded(
          child: isRecording
              ? _PillButton(
                  key: const Key('voiceStop'),
                  icon: Icons.stop,
                  background: colors.danger,
                  foreground: colors.onAccent,
                  onPressed: onStop,
                  semanticLabel: 'Arrêter l\'enregistrement',
                )
              : _PillButton(
                  key: const Key('voiceRecord'),
                  icon: Icons.mic,
                  background: hasRecording
                      ? _disabledFill(colors)
                      : colors.record,
                  foreground: hasRecording
                      ? _disabledInk(colors)
                      : colors.onRecord,
                  // Une fois enregistré, le milieu s'éteint : reprendre passe
                  // par « Recommencer », qui dit clairement qu'on efface.
                  onPressed: hasRecording ? null : onRecord,
                  semanticLabel: 'Enregistrer un message vocal',
                ),
        ),
        const SizedBox(width: VoiceRecorderPanel.margin),
        Expanded(
          child: _PillButton(
            key: const Key('voiceAttach'),
            label: 'Joindre',
            icon: Icons.check,
            background: onAttach == null
                ? _disabledFill(colors)
                : colors.accent,
            foreground: onAttach == null
                ? _disabledInk(colors)
                : colors.onAccent,
            onPressed: onAttach,
          ),
        ),
      ],
    );
  }
}

/// Un bouton éteint, aux opacités de Material 3 : 12 % pour le fond, 38 %
/// pour l'encre. C'est ce gris-là qu'affiche l'app d'origine — un `surfaceAlt`
/// laisserait un bouton d'aplomb, qui n'aurait l'air éteint que par son
/// libellé.
Color _disabledFill(AppColors colors) =>
    colors.textPrimary.withValues(alpha: 0.12);

Color _disabledInk(AppColors colors) =>
    colors.textPrimary.withValues(alpha: 0.38);

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.semanticLabel,
  });

  final String? label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = label;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(VoiceRecorderPanel.buttonHeight / 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: VoiceRecorderPanel.buttonHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: foreground,
                semanticLabel: semanticLabel,
              ),
              if (text != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La piste d'un enregistrement en cours.
///
/// **Ancrée à droite** : le relevé le plus récent est au bord droit, et les
/// précédents défilent vers la gauche jusqu'à sortir de la piste. C'est ce que
/// fait l'app d'origine — vérifié à l'émulateur, où la piste part du bord
/// droit à deux secondes, atteint le bord gauche vers cinq, puis défile.
///
/// La géométrie est celle de la piste d'une bulle ([AudioTrackPainter]) : une
/// barre de 3 dp tous les 7 dp, et une hauteur minimale qui fait qu'un silence
/// se dessine en **point** plutôt qu'en trou. C'est ce minimum qui donne à un
/// enregistrement muet l'allure pointillée de l'app d'origine, sans qu'aucun
/// dessin ne soit inventé pour ce cas-là.
///
/// Public pour que les tests lisent ce qu'on lui donne à dessiner.
class VoiceLevelsPainter extends CustomPainter {
  VoiceLevelsPainter({required this.waveform, required this.color});

  final Waveform waveform;
  final Color color;

  static const barWidth = 3.0;
  static const barGap = 4.0;
  static const minBarHeight = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final slots = ((size.width + barGap) / (barWidth + barGap)).floor();
    if (slots <= 0) return;

    // Seuls les derniers relevés tiennent dans la piste : les plus anciens en
    // sont sortis, comme sur une bande qui défile.
    final levels = waveform.levels.length <= slots
        ? waveform.levels
        : waveform.levels.sublist(waveform.levels.length - slots);
    if (levels.isEmpty) return;

    final middle = size.height / 2;
    final paint = Paint()..color = color;
    // Le dernier relevé touche le bord droit : c'est là qu'est l'instant
    // présent, et c'est vers la gauche que le passé s'éloigne.
    final right = size.width;

    for (var index = 0; index < levels.length; index++) {
      final fromRight = levels.length - 1 - index;
      final left = right - barWidth - fromRight * (barWidth + barGap);
      if (left + barWidth < 0) continue;
      final height =
          minBarHeight + levels[index] * (size.height - minBarHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, middle - height / 2, barWidth, height),
          const Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceLevelsPainter old) =>
      old.color != color || !identical(old.waveform, waveform);
}
