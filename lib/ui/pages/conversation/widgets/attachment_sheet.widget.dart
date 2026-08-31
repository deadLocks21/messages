import 'package:flutter/material.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Ce qu'une case du panneau déclenche.
///
/// Les quatre premières sont des **sources** du domaine : un écran du système
/// s'ouvre, et ce qui en revient est une pièce jointe. [gif] n'en est pas une —
/// il n'y a pas d'écran à ouvrir mais un catalogue à parcourir, sous le champ
/// de rédaction. D'où [source], nul pour lui seul : le panneau des sources
/// n'est pas le seul chemin vers une pièce jointe, et cette énumération est le
/// seul endroit où cela se voit.
enum AttachmentChoice {
  gallery(AttachmentSource.gallery, Icons.image_outlined, 'Galerie'),
  camera(AttachmentSource.camera, Icons.photo_camera_outlined, 'Appareil photo'),
  gif(null, Icons.gif_box_outlined, 'GIF'),
  files(AttachmentSource.files, Icons.attach_file, 'Fichiers'),
  contactCard(AttachmentSource.contactCard, Icons.person_outline, 'Contact');

  final AttachmentSource? source;
  final IconData icon;
  final String label;

  const AttachmentChoice(this.source, this.icon, this.label);
}

/// Le panneau qui monte du bas quand on touche « + » dans le champ de
/// rédaction : une grille de sources, trois par ligne, chacune une pastille
/// arrondie surmontant son libellé — la disposition de Google Messages, dont
/// les trois premières cases sont ici les mêmes, dans le même ordre.
///
/// Seules les sources que l'app sait réellement honorer y figurent. L'app
/// d'origine en montre d'autres (autocollants, localisation) qui relèvent du
/// RCS : les afficher grisées ferait un panneau plus fidèle mais promettrait
/// ce qu'un MMS ne peut pas tenir. Le **GIF**, lui, y figure désormais : un GIF
/// est une image, et une image tient dans un MMS.
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  /// Ouvre le panneau et rend le choix fait, ou null si l'utilisateur le
  /// referme.
  static Future<AttachmentChoice?> show(BuildContext context) {
    return showModalBottomSheet<AttachmentChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const AttachmentSheet(),
    );
  }

  static const _choices = AttachmentChoice.values;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      key: const Key('attachmentSheet'),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // La poignée : c'est elle qui dit que le panneau se referme en
              // le tirant vers le bas.
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // `mainAxisExtent` plutôt qu'un rapport d'aspect : la hauteur
              // d'une case est celle de la pastille et de son libellé, elle ne
              // doit pas dépendre de la largeur de l'écran.
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 118,
                      mainAxisSpacing: 8,
                    ),
                itemCount: _choices.length,
                itemBuilder: (context, index) => _SourceButton(
                  choice: _choices[index],
                  onTap: () => Navigator.of(context).pop(_choices[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.choice, required this.onTap});

  final AttachmentChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('attachFrom_${choice.name}'),
              onTap: onTap,
              child: SizedBox(
                height: 72,
                width: double.infinity,
                child: Icon(choice.icon, size: 26, color: colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            choice.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
