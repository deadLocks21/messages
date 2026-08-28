import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Aperçu carré d'une pièce jointe, du plateau de rédaction comme d'une bulle.
///
/// Les octets arrivent après coup (lecture du stock ou du fichier choisi) :
/// tant qu'ils manquent, la vignette reste une plaque neutre plutôt qu'un
/// tourniquet — un fil qui charge dix images ne doit pas se mettre à clignoter.
/// Une image illisible retombe sur l'icône de sa nature, jamais sur une croix
/// rouge de framework.
class AttachmentThumbnail extends StatelessWidget {
  const AttachmentThumbnail({
    super.key,
    required this.kind,
    required this.bytes,
    required this.width,
    double? height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : height = height ?? width;

  final AttachmentKind kind;
  final Uint8List? bytes;
  final double width;

  /// Par défaut carrée — c'est la forme du plateau de rédaction. Une bulle, qui
  /// connaît le rapport de l'image, la donne explicitement.
  final double height;

  /// Coins de la vignette. Dans une bulle, ce sont **ceux de la bulle** : une
  /// image reçue n'est pas posée sur un message, elle en tient lieu.
  final BorderRadius borderRadius;

  static IconData iconFor(AttachmentKind kind) => switch (kind) {
    AttachmentKind.image => Icons.image_outlined,
    AttachmentKind.video => Icons.movie_outlined,
    AttachmentKind.audio => Icons.graphic_eq,
    AttachmentKind.vcard => Icons.person_outline,
    AttachmentKind.file => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final data = bytes;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.surfaceAlt),
            if (kind == AttachmentKind.image && data != null)
              Image.memory(
                data,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // Décoder à la taille d'affichage, pas à celle du capteur : une
                // photo de 12 Mpx occuperait 48 Mo en mémoire pour remplir une
                // vignette de 76 px. Quelques images suffisaient à faire tomber
                // l'app.
                cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => _Placeholder(kind: kind),
              )
            else
              _Placeholder(kind: kind),
            // Une vidéo ne se décode pas ici : elle se signale par son
            // pastillage, et s'ouvre dans le lecteur du système.
            if (kind == AttachmentKind.video)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.kind});

  final AttachmentKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Icon(
        AttachmentThumbnail.iconFor(kind),
        color: colors.textMuted,
        size: 26,
      ),
    );
  }
}
