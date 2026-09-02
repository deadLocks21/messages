import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/conversation_details.dto.dart';
import 'package:messages/core/application/usecases/update_conversation_flags.usecase.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/ui/pages/conversation/widgets/conversation_menu.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/details_action_pill.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/details_card.widget.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Les détails d'un fil : qui est en face, ce qu'on peut faire de lui, et les
/// réglages du fil.
///
/// C'est l'écran qu'ouvre un appui sur le nom, en haut d'une conversation —
/// comme dans l'app d'origine, où le nom et la pastille forment un seul bouton
/// (`top_app_bar_title_row`). Le menu « ⋮ » y mène aussi, par « Détails ».
///
/// La mise en page est relevée au pixel sur l'app d'origine (émulateur
/// Android 16, 1080×2400 à 2,625 px/dp) : pastille de 96, nom en 24, numéro en
/// 16, boutons ronds de 56 de haut, lignes de réglage de 56 dans des cartes de
/// 12 de rayon séparées de 2.
class ConversationDetailsPage extends ConsumerStatefulWidget {
  const ConversationDetailsPage({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ConversationDetailsPage> createState() =>
      _ConversationDetailsPageState();
}

class _ConversationDetailsPageState
    extends ConsumerState<ConversationDetailsPage> {
  final ScrollController _scroll = ScrollController();

  /// Opacité du titre de la barre. Dans l'app d'origine la barre est nue tant
  /// que le nom est visible dans l'en-tête — il n'y est écrit qu'une fois, et
  /// le titre ne prend le relais que lorsque l'en-tête passe dessous.
  ///
  /// Un `ValueNotifier` plutôt qu'un `setState` : le défilement rebâtirait
  /// sinon tout l'écran à chaque image.
  final ValueNotifier<double> _titleOpacity = ValueNotifier(0);

  /// Là où le nom de l'en-tête arrive sous la barre : pastille (96) + écart
  /// (24), moins la hauteur du fondu.
  static const _fadeStart = 104.0;
  static const _fadeLength = 32.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _titleOpacity.dispose();
    super.dispose();
  }

  void _onScroll() {
    _titleOpacity.value = ((_scroll.offset - _fadeStart) / _fadeLength).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(conversationDetailsProvider(widget.threadId));

    return Scaffold(
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Fil introuvable')),
        data: (details) => details == null
            ? const Center(child: Text('Fil introuvable'))
            : _body(details),
      ),
    );
  }

  Widget _body(ConversationDetailsDto details) {
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        _appBar(details),
        SliverToBoxAdapter(child: _header(details)),
        SliverToBoxAdapter(child: _options(details)),
        SliverToBoxAdapter(child: _members(details)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _appBar(ConversationDetailsDto details) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 64,
      title: ValueListenableBuilder<double>(
        valueListenable: _titleOpacity,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Text(
          details.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }

  /// L'en-tête : pastille, nom, numéro, et la rangée de boutons ronds.
  Widget _header(ConversationDetailsDto details) {
    final colors = context.appColors;
    final conversation = details.conversation;
    final sole = details.soleParticipant;

    // Le nom et le numéro sont les seuls textes de l'app teintés par la
    // palette primaire — relevé #001849 en clair, #DAE2FF en sombre, quand les
    // lignes des cartes, elles, restent au neutre.
    final headline = TextStyle(color: colors.onAccentSoft, height: 32 / 24);

    return Padding(
      // 24 sous le dernier libellé : c'est ce qui sépare l'en-tête de la
      // première carte dans l'app d'origine.
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Avatar(avatar: conversation.avatar, size: 96),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              conversation.title,
              textAlign: TextAlign.center,
              style: headline.copyWith(fontSize: 24),
            ),
          ),
          // Le numéro n'a sa ligne que sous un nom : pour un numéro sans
          // fiche, le titre *est* le numéro, et l'app d'origine ne l'écrit pas
          // deux fois.
          //
          // Les écarts sont relevés au pixel : 8 au-dessus du numéro, 16 en
          // dessous — soit exactement les 48 qui séparent le nom des boutons
          // quand il n'y a pas de numéro du tout.
          if (sole != null && sole.addressLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              key: const Key('copyAddress'),
              onTap: () => _copy(sole.rawAddress),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  sole.addressLabel,
                  textAlign: TextAlign.center,
                  style: headline.copyWith(fontSize: 16, height: 24 / 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 24),
          if (sole != null) _actions(sole),
        ],
      ),
    );
  }

  /// Les boutons ronds. Ils ne s'affichent qu'à deux : dans un groupe il n'y a
  /// pas *un* numéro à appeler, ni *une* fiche à ouvrir.
  Widget _actions(ParticipantDto sole) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DetailsActionPill(
              key: const Key('callParticipant'),
              icon: Icons.call,
              label: 'Appeler',
              onTap: () => _call(sole.rawAddress),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: sole.isKnown
                ? DetailsActionPill(
                    key: const Key('openContactCard'),
                    icon: Icons.person,
                    label: 'Infos contact',
                    onTap: () => _openCard(sole.contactId!),
                  )
                : DetailsActionPill(
                    key: const Key('addContact'),
                    icon: Icons.person_add,
                    label: 'Ajouter un contact',
                    onTap: () => _createCard(sole.rawAddress),
                  ),
          ),
        ],
      ),
    );
  }

  /// Les réglages du fil, une carte par ligne comme dans l'app d'origine.
  Widget _options(ConversationDetailsDto details) {
    final colors = context.appColors;
    final conversation = details.conversation;

    return Column(
      children: [
        DetailsCardRow(
          key: const Key('togglePinned'),
          icon: Icons.push_pin_outlined,
          label: conversation.isPinned ? 'Ne plus épingler' : 'Épingler',
          onTap: () => _flag((f) => f.togglePinned(widget.threadId)),
        ),
        DetailsCardRow(
          key: const Key('toggleMuted'),
          icon: conversation.isMuted
              ? Icons.notifications_outlined
              : Icons.notifications_off_outlined,
          label: conversation.isMuted
              ? 'Réactiver les notifications'
              : 'Sourdine',
          onTap: () => _flag((f) => f.toggleMuted(widget.threadId)),
        ),
        DetailsCardRow(
          key: const Key('toggleArchived'),
          icon: conversation.isArchived
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
          label: conversation.isArchived ? 'Désarchiver' : 'Archiver',
          onTap: () => _flag((f) => f.toggleArchived(widget.threadId)),
        ),
        // La ligne rouge de l'app d'origine est « Bloquer et signaler comme
        // spam », que l'app ne sait pas faire. C'est « Supprimer » qui prend
        // sa place : la seule action de cet écran dont on ne revient pas.
        DetailsCardRow(
          key: const Key('deleteThread'),
          icon: Icons.delete_outline,
          label: 'Supprimer la conversation',
          color: colors.danger,
          onTap: _delete,
        ),
      ],
    );
  }

  Widget _members(ConversationDetailsDto details) {
    final participants = details.participants;
    if (participants.isEmpty) return const SizedBox.shrink();

    return DetailsCard(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 6),
      child: Column(
        children: [
          DetailsCardHeader(
            participants.length == 1
                ? '1 autre personne'
                : '${participants.length} autres personnes',
          ),
          for (final participant in participants)
            DetailsMemberRow(
              participant: participant,
              onTap: participant.isKnown
                  ? () => _openCard(participant.contactId!)
                  : () => _createCard(participant.rawAddress),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    // Android 13+ affiche sa propre vignette de presse-papiers, et l'app
    // d'origine ne dit rien de plus. En deçà, rien ne signalerait la copie.
    _announce('Numéro copié');
  }

  Future<void> _call(String address) async {
    final uri = Uri(scheme: 'tel', path: address);
    if (!await launchUrl(uri)) {
      await ref.read(loggerProvider).warn('call.launch_failed');
      _announce('Aucune application d\'appel disponible.');
    }
  }

  Future<void> _openCard(String contactId) async {
    final opened = await ref.read(contactCardServiceProvider).open(contactId);
    if (!opened) _announce('Aucune application de contacts disponible.');
  }

  Future<void> _createCard(String address) async {
    final opened = await ref.read(contactCardServiceProvider).create(address);
    if (!opened) _announce('Aucune application de contacts disponible.');
  }

  /// Un réglage bascule, puis les deux vues qui l'affichent se rechargent :
  /// cet écran, et la liste qu'on retrouvera en sortant.
  Future<void> _flag(
    Future<void> Function(UpdateConversationFlagsUseCase) toggle,
  ) async {
    await toggle(ref.read(updateConversationFlagsUseCaseProvider));
    if (!mounted) return;
    ref.invalidate(conversationDetailsProvider(widget.threadId));
    ref.invalidate(conversationProvider(widget.threadId));
    ref.invalidate(conversationsProvider);
  }

  Future<void> _delete() async {
    final confirmed = await ConversationMenu.confirmDelete(context);
    if (confirmed != true || !mounted) return;
    await ref.read(deleteConversationUseCaseProvider).execute(widget.threadId);
    if (!mounted) return;
    ref.invalidate(conversationsProvider);
    // Le fil dont on vient n'existe plus : on ne peut pas y revenir d'un
    // `pop`, il faut repartir de la liste.
    context.go(AppRoutes.conversations);
  }

  void _announce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
