import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/ui/providers/audio_providers.dart';

/// Un vocal dans sa bulle : bouton, avancement, durée.
///
/// Une pièce jointe sonore n'a rien à montrer — ni vignette, ni nom de fichier
/// utile (« Audio », « part-3.amr »). Ce qu'on en attend est de l'écouter, et
/// de savoir avant de commencer combien de temps cela va prendre : c'est
/// exactement ce que porte cette ligne, comme dans l'app d'origine.
///
/// Le lecteur est ailleurs (`AudioPlayerService`) et n'existe qu'en un
/// exemplaire : cette bulle-ci ne joue pas, elle reconnaît sa pièce jointe dans
/// l'état publié. Lancer un autre vocal la ramène donc d'elle-même à son bouton
/// « lire ».
class AudioAttachment extends ConsumerWidget {
  const AudioAttachment({
    super.key,
    required this.attachment,
    required this.foreground,
    required this.background,
    required this.maxWidth,
  });

  final AttachmentDto attachment;

  /// Couleur du texte de la bulle : le bouton s'y peint plein…
  final Color foreground;

  /// …et son icône se découpe dans le fond. Une bulle envoyée et une bulle
  /// reçue n'ont pas le même contraste ; les deux couleurs viennent donc d'elle.
  final Color background;

  final double maxWidth;

  static const _buttonSize = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback =
        ref.watch(audioPlaybackProvider).value ?? AudioPlayback.idle;
    final mine = playback.isFor(attachment.id);
    final playing = mine && playback.isPlaying;

    // La durée annoncée par le stock tient lieu de repère jusqu'à ce que le
    // lecteur ouvre le fichier et donne la vraie.
    final total = mine && playback.duration > Duration.zero
        ? playback.duration
        : attachment.duration;
    final position = mine ? playback.position : Duration.zero;

    return SizedBox(
      width: maxWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        child: Row(
          children: [
            _PlayButton(
              id: attachment.id,
              playing: playing,
              foreground: foreground,
              background: background,
              onPressed: () {
                final player = ref.read(audioPlayerServiceProvider);
                if (playing) {
                  player.pause();
                } else {
                  player.play(attachment.id);
                }
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ProgressTrack(
                key: Key('audioTrack_${attachment.id}'),
                progress: mine ? playback.progress : 0,
                color: foreground,
                // Sans durée connue, il n'y a nulle part où se déplacer : le
                // curseur reste au départ plutôt que de sauter au hasard.
                onSeek: total == null || total == Duration.zero
                    ? null
                    : (fraction) => ref
                          .read(audioPlayerServiceProvider)
                          .seek(attachment.id, total * fraction),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              // Au repos, la bulle annonce la longueur du vocal ; une fois
              // lancée, elle dit où on en est.
              mine
                  ? AttachmentDto.formatDuration(position)
                  : attachment.durationLabel,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                // Chiffres de largeur fixe : sans cela, le libellé se
                // dandinerait à chaque seconde qui passe.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.id,
    required this.playing,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final String id;
  final bool playing;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  /// Rayon du carré arrondi que devient le bouton pendant la lecture.
  static const playingRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    // Rond au repos, carré arrondi pendant la lecture : la forme porte l'état
    // autant que l'icône. De loin, ou du coin de l'œil dans un fil qui défile,
    // un disque et un carré arrondi se distinguent là où deux glyphes de 24 px
    // se ressemblent.
    //
    // C'est un bouton **à bascule** de Material, pas un carré peint à la main :
    // `isSelected` porte l'état, la forme se résout par état comme n'importe
    // quelle autre propriété du style, et c'est `Material` qui interpole d'une
    // forme à l'autre — le cercle et le rectangle arrondi savent se fondre l'un
    // dans l'autre. Rien à animer nous-mêmes, et l'encre, le survol et la cible
    // tactile de 48 px viennent avec.
    return IconButton(
      key: Key('playAttachment_$id'),
      onPressed: onPressed,
      isSelected: playing,
      icon: const Icon(
        Icons.play_arrow,
        semanticLabel: 'Écouter le message audio',
      ),
      selectedIcon: const Icon(Icons.pause, semanticLabel: 'Mettre en pause'),
      iconSize: 24,
      style:
          IconButton.styleFrom(
            backgroundColor: foreground,
            foregroundColor: background,
            fixedSize: const Size.square(AudioAttachment._buttonSize),
            padding: EdgeInsets.zero,
          ).copyWith(
            shape: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(playingRadius),
                    )
                  : const CircleBorder(),
            ),
          ),
    );
  }
}

/// La piste pointillée de l'app d'origine, et la tête de lecture qui la
/// parcourt.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    super.key,
    required this.progress,
    required this.color,
    required this.onSeek,
  });

  final double progress;
  final Color color;

  /// Reçoit une fraction entre 0 et 1. `null` quand la durée est inconnue.
  final ValueChanged<double>? onSeek;

  /// Assez haut pour que le doigt attrape la piste sans viser les points.
  static const _hitHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seekAt(Offset local) =>
            onSeek?.call((local.dx / width).clamp(0.0, 1.0));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seekAt(details.localPosition),
          onHorizontalDragUpdate: (details) => seekAt(details.localPosition),
          child: SizedBox(
            width: width,
            height: _hitHeight,
            child: CustomPaint(
              painter: _TrackPainter(progress: progress, color: color),
            ),
          ),
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _spacing = 7.0;
  static const _dotRadius = 1.6;
  static const _headRadius = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    // La tête reste entière aux deux bouts : sans cette marge, elle serait
    // coupée en moitié au départ et à l'arrivée.
    final travel = size.width - _headRadius * 2;
    if (travel <= 0) return;
    final headX = _headRadius + travel * progress.clamp(0.0, 1.0);

    final dot = Paint()..color = color.withValues(alpha: 0.32);
    for (var x = _headRadius; x <= size.width - _headRadius; x += _spacing) {
      // Les points que la tête recouvre ne sont pas dessinés : ils
      // l'empâteraient au lieu de la souligner.
      if ((x - headX).abs() < _headRadius + 1.5) continue;
      canvas.drawCircle(Offset(x, y), _dotRadius, dot);
    }
    canvas.drawCircle(Offset(headX, y), _headRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.progress != progress || old.color != color;
}
