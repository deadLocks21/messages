import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/ui/pages/conversations/widgets/account_sheet.widget.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';

/// La barre de l'écran d'accueil : le nom de l'app à gauche, la loupe et la
/// pastille de compte à droite, sur le fond pêche du thème.
///
/// Pas de champ de recherche ici — comme dans Google Messages, la loupe ouvre
/// un écran de recherche dédié.
class MessagesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MessagesAppBar({super.key});

  static const _height = 64.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppBar(
      toolbarHeight: _height,
      titleSpacing: 24,
      title: Text(
        'Messages',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 23,
          fontWeight: FontWeight.w400,
        ),
      ),
      actions: [
        IconButton(
          key: const Key('openSearch'),
          tooltip: 'Rechercher',
          icon: const Icon(Icons.search, size: 26),
          onPressed: () => context.push(AppRoutes.search),
        ),
        const SizedBox(width: 4),
        const _AccountButton(),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// Pastille de compte : donne accès aux archives et aux paramètres, là où
/// Google Messages loge le menu du compte Google.
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      label: 'Compte',
      child: InkResponse(
        key: const Key('accountMenu'),
        onTap: () => AccountSheet.show(context),
        radius: 26,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.person, size: 22, color: colors.onAccentSoft),
        ),
      ),
    );
  }
}
