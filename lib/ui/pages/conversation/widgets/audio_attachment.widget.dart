import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/domain/model/audio_playback.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/ui/providers/audio_providers.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Un vocal dans sa bulle : bouton, piste, durée.
///
/// Une pièce jointe sonore n'a rien à montrer — ni vignette, ni nom de fichier
/// utile (« Audio », « part-3.amr »). Ce qu'on en attend est de l'écouter, et
/// de savoir avant de commencer combien de temps cela va prendre : c'est
/// exactement ce que porte cette ligne, comme dans l'app d'origine.
///
/// **Une piste, pas une silhouette.** L'app d'origine ne dessine pas le relief
/// du son sur un MMS : elle y pose un curseur Material 3 — piste en gélule,
/// tête de lecture en barre, pastille de fin — et rien d'autre. Le relief,
/// elle le garde pour le panneau d'enregistrement, où il dit que le micro
/// entend ; dans la bulle il ne dirait rien qu'on ne sache déjà.
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
    required this.maxWidth,
  });

  final AttachmentDto attachment;

  /// Couleur du texte de la bulle. Le lecteur ne s'en peint pas — il a son
  /// propre ton — mais il en tire ses deux gris : la piste qui reste à jouer et
  /// le libellé de durée, qui ne sont que ce texte-là très effacé.
  final Color foreground;

  /// Ce que la bulle laisse de large. Le lecteur ne le prend pas tout : voir
  /// [_width].
  final double maxWidth;

  static const _buttonSize = 40.0;

  /// Hauteur du curseur — celle de sa tête de lecture, la plus haute pièce de
  /// la ligne. Relevé 44 dp.
  static const _sliderHeight = 44.0;

  /// Le lecteur ne s'étire pas jusqu'au bord comme le fait un texte long :
  /// l'app d'origine lui donne une largeur à lui, plus courte que la bulle la
  /// plus large (relevé 296 dp de bulle sur un écran de 411 dp, quand un
  /// paragraphe y monte à 324). Une piste qui traverserait l'écran donnerait à
  /// trois secondes de voix l'air d'un morceau.
  ///
  /// Les 8 dp retirés sont le rembourrage que la bulle a déjà posé autour de
  /// ses pièces jointes : c'est la bulle entière qui doit mesurer 296.
  static const _intrinsicWidth = 296.0 - 8;

  double get _width => math.min(maxWidth, _intrinsicWidth);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final playback =
        ref.watch(audioPlaybackProvider).value ?? AudioPlayback.idle;
    final mine = playback.isFor(attachment.id);
    final playing = mine && playback.isPlaying;

    // La durée annoncée par le stock tient lieu de repère jusqu'à ce que le
    // lecteur ouvre le fichier et donne la vraie.
    final total = mine && playback.duration > Duration.zero
        ? playback.duration
        : attachment.duration;

    return SizedBox(
      width: _width,
      child: Padding(
        // 12 de côté et 10 en hauteur, par-dessus les 4 de la bulle : 16 et 14
        // depuis son bord, comme dans l'app d'origine.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SizedBox(
          height: _sliderHeight,
          child: Row(
            children: [
              _PlayButton(
                id: attachment.id,
                playing: playing,
                foreground: colors.audioControl,
                background: colors.onAudioControl,
                onPressed: () {
                  final player = ref.read(audioPlayerServiceProvider);
                  if (playing) {
                    player.pause();
                  } else {
                    player.play(attachment.id);
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ProgressTrack(
                  key: Key('audioTrack_${attachment.id}'),
                  progress: mine ? playback.progress : 0,
                  color: colors.audioControl,
                  // Ce qui reste à jouer n'est pas une couleur à soi : c'est le
                  // texte de la bulle, à peine posé dessus.
                  trackColor: foreground.withValues(alpha: 0.12),
                  // Sans durée connue, il n'y a nulle part où se déplacer : le
                  // curseur reste au départ plutôt que de sauter au hasard.
                  onSeek: total == null || total == Duration.zero
                      ? null
                      : (fraction) => ref
                            .read(audioPlayerServiceProvider)
                            .seek(attachment.id, total * fraction),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                // Au repos, la bulle annonce la longueur du vocal ; une fois
                // lancée, elle dit où on en est.
                mine
                    ? AttachmentDto.formatDuration(playback.position)
                    : attachment.durationLabel,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.6),
                  fontSize: 13,
                  // Chiffres de largeur fixe : sans cela, le libellé se
                  // dandinerait à chaque seconde qui passe.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
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
  static const playingRadius = 12.0;

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
    // dans l'autre. Rien à animer nous-mêmes, et l'encre et le survol viennent
    // avec.
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
            // Le bouton mesure ce qu'il montre : la cible de 48 dp de Material
            // rendrait la ligne plus haute que la bulle de l'app d'origine, et
            // pousserait la piste vers la droite. Le doigt y perd peu — 40 dp
            // de disque, et toute la piste à côté pour reprendre la lecture.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Le curseur de l'app d'origine : deux gélules séparées par la tête de
/// lecture, et la pastille qui marque la fin.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    super.key,
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.onSeek,
  });

  final double progress;

  /// La tête de lecture, la part jouée, la pastille de fin.
  final Color color;

  /// La part qui reste à jouer.
  final Color trackColor;

  /// Reçoit une fraction entre 0 et 1. `null` quand la durée est inconnue.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // La tête ne sort pas de la piste : son centre ne va que d'un
        // demi-doigt du bord à l'autre. Une fraction se lit donc sur ce
        // trajet-là, pas sur la largeur entière.
        final travel = math.max(width - AudioTrackPainter.thumbWidth, 1.0);
        void seekAt(Offset local) => onSeek?.call(
          ((local.dx - AudioTrackPainter.thumbWidth / 2) / travel).clamp(
            0.0,
            1.0,
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seekAt(details.localPosition),
          onHorizontalDragUpdate: (details) => seekAt(details.localPosition),
          child: CustomPaint(
            size: Size(width, AudioAttachment._sliderHeight),
            painter: AudioTrackPainter(
              progress: progress,
              color: color,
              trackColor: trackColor,
            ),
          ),
        );
      },
    );
  }
}

/// Le dessin du curseur.
///
/// Public pour que les tests puissent vérifier ce qu'on lui donne à dessiner —
/// c'est là que se voit où en est la lecture.
class AudioTrackPainter extends CustomPainter {
  AudioTrackPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  /// La tête de lecture : une barre, pas une bille. Relevé 4 × 44 dp.
  static const thumbWidth = 4.0;
  static const thumbHeight = 44.0;

  /// La piste, de part et d'autre de la tête. Relevé 16 dp de haut.
  static const trackHeight = 16.0;

  /// L'air laissé entre la tête et chacune des deux gélules — c'est lui qui
  /// fait lire la tête comme une tête, et non comme la fin de la piste.
  static const thumbGap = 6.0;

  /// La pastille de fin : elle dit où la piste s'arrête, quand la part qui
  /// reste est trop courte pour se voir. Relevé 4 dp, à 6 dp du bout.
  static const stopRadius = 2.0;
  static const stopInset = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    final travel = math.max(size.width - thumbWidth, 0.0);
    final thumbCenter =
        thumbWidth / 2 + travel * progress.clamp(0.0, 1.0);
    final radius = Radius.circular(trackHeight / 2);

    void pill(double left, double right, Color paint) {
      if (right - left <= 0) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, middle - trackHeight / 2, right, middle + trackHeight / 2),
          radius,
        ),
        Paint()..color = paint,
      );
    }

    // Ce qui est joué à gauche, ce qui reste à droite, la tête entre les deux.
    pill(0, thumbCenter - thumbWidth / 2 - thumbGap, color);
    final restStart = thumbCenter + thumbWidth / 2 + thumbGap;
    pill(restStart, size.width, trackColor);

    // La pastille ne se pose que sur la piste qui reste : passée dessus, la
    // tête l'a déjà mangée.
    final stopX = size.width - stopInset - stopRadius;
    if (stopX - stopRadius > restStart) {
      canvas.drawCircle(Offset(stopX, middle), stopRadius, Paint()..color = color);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          thumbCenter - thumbWidth / 2,
          middle - thumbHeight / 2,
          thumbWidth,
          thumbHeight,
        ),
        const Radius.circular(thumbWidth / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(AudioTrackPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
