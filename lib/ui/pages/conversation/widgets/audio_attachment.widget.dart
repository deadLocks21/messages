import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/core/domain/model/waveform.dart';
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
                // Mesurée à l'arrivée de la bulle : tant qu'elle manque, la
                // piste reste la ligne pointillée neutre.
                waveform:
                    ref.watch(audioWaveformProvider(attachment.id)).value ??
                    Waveform.empty,
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
    required this.waveform,
    required this.onSeek,
  });

  final double progress;
  final Color color;

  /// Relief du son. Vide tant qu'il n'est pas mesuré, ou s'il ne l'a pas été.
  final Waveform waveform;

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
              painter: AudioTrackPainter(
                progress: progress,
                color: color,
                waveform: waveform,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Le dessin de la piste : les barres du son, ou la ligne pointillée quand il
/// n'a pas pu être mesuré.
///
/// Public pour que les tests puissent vérifier ce qu'on lui donne à dessiner —
/// c'est là que se voit si la bulle a bien demandé, puis transmis, la mesure.
class AudioTrackPainter extends CustomPainter {
  AudioTrackPainter({
    required this.progress,
    required this.color,
    required this.waveform,
  });

  final double progress;
  final Color color;
  final Waveform waveform;

  /// Barres : ce que le son a réellement fait.
  static const _barWidth = 3.0;
  static const _barGap = 2.0;

  /// Un silence reste une barre : sans ce minimum, la piste se troue et on ne
  /// sait plus où poser le doigt.
  static const _minBarHeight = 3.0;

  /// Points : la piste neutre, tant qu'il n'y a rien de mesuré à montrer.
  static const _dotSpacing = 7.0;
  static const _dotRadius = 1.6;
  static const _headRadius = 4.5;

  /// Ce qui est déjà passé se lit plein, ce qui reste en retrait.
  static const _pendingAlpha = 0.32;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) {
      _paintDots(canvas, size);
      return;
    }
    _paintBars(canvas, size);
  }

  void _paintBars(Canvas canvas, Size size) {
    final count = ((size.width + _barGap) / (_barWidth + _barGap)).floor();
    if (count <= 0) return;
    final levels = waveform.resampled(count);
    final middle = size.height / 2;

    final bars = [
      for (var index = 0; index < levels.length; index++)
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            index * (_barWidth + _barGap),
            middle -
                (_minBarHeight + levels[index] * (size.height - _minBarHeight)) /
                    2,
            _barWidth,
            _minBarHeight + levels[index] * (size.height - _minBarHeight),
          ),
          const Radius.circular(_barWidth / 2),
        ),
    ];

    final pending = Paint()..color = color.withValues(alpha: _pendingAlpha);
    for (final bar in bars) {
      canvas.drawRRect(bar, pending);
    }

    // Le trait de partage tombe là où en est la lecture, pas au bord de la
    // barre la plus proche : la barre en cours se remplit peu à peu, et
    // l'avancée devient continue au lieu de sauter d'une barre à l'autre.
    final played = size.width * progress.clamp(0.0, 1.0);
    if (played <= 0) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, played, size.height));
    final done = Paint()..color = color;
    for (final bar in bars) {
      canvas.drawRRect(bar, done);
    }
    canvas.restore();
  }

  void _paintDots(Canvas canvas, Size size) {
    final y = size.height / 2;
    // La tête reste entière aux deux bouts : sans cette marge, elle serait
    // coupée en moitié au départ et à l'arrivée.
    final travel = size.width - _headRadius * 2;
    if (travel <= 0) return;
    final headX = _headRadius + travel * progress.clamp(0.0, 1.0);

    final dot = Paint()..color = color.withValues(alpha: _pendingAlpha);
    for (var x = _headRadius; x <= size.width - _headRadius; x += _dotSpacing) {
      // Les points que la tête recouvre ne sont pas dessinés : ils
      // l'empâteraient au lieu de la souligner.
      if ((x - headX).abs() < _headRadius + 1.5) continue;
      canvas.drawCircle(Offset(x, y), _dotRadius, dot);
    }
    canvas.drawCircle(Offset(headX, y), _headRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(AudioTrackPainter old) =>
      old.progress != progress ||
      old.color != color ||
      !identical(old.waveform, waveform);
}
