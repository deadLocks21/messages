import 'package:flutter/material.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// Le panneau qui monte du bas quand on touche « + » dans le champ de
/// rédaction : une grille de sources, trois par ligne, chacune une pastille
/// arrondie surmontant son libellé — la disposition de Google Messages.
///
/// Seules les sources que l'app sait réellement honorer y figurent. L'app
/// d'origine en montre d'autres (GIF, autocollants, localisation) qui relèvent
/// du RCS : les afficher grisées ferait un panneau plus fidèle mais promettrait
/// ce qu'un MMS ne peut pas tenir.
class AttachmentSheet extends StatelessWidget {
  const AttachmentSheet({super.key});

  /// Ouvre le panneau et rend la source choisie, ou null si l'utilisateur le
  /// referme.
  static Future<AttachmentSource?> show(BuildContext context) {
    return showModalBottomSheet<AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const AttachmentSheet(),
    );
  }

  static const _sources = <_SourceTile>[
    _SourceTile(AttachmentSource.gallery, Icons.image_outlined, 'Galerie'),
    _SourceTile(
      AttachmentSource.camera,
      Icons.photo_camera_outlined,
      'Appareil photo',
    ),
    _SourceTile(AttachmentSource.files, Icons.attach_file, 'Fichiers'),
    _SourceTile(
      AttachmentSource.contactCard,
      Icons.person_outline,
      'Contact',
    ),
  ];

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
                itemCount: _sources.length,
                itemBuilder: (context, index) => _SourceButton(
                  tile: _sources[index],
                  onTap: () =>
                      Navigator.of(context).pop(_sources[index].source),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile {
  final AttachmentSource source;
  final IconData icon;
  final String label;

  const _SourceTile(this.source, this.icon, this.label);
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.tile, required this.onTap});

  final _SourceTile tile;
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
              key: Key('attachFrom_${tile.source.name}'),
              onTap: onTap,
              child: SizedBox(
                height: 72,
                width: double.infinity,
                child: Icon(tile.icon, size: 26, color: colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tile.label,
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
