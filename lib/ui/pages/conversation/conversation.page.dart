import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/usecases/save_draft.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_sheet.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_tray.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/conversation_menu.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/expression_picker.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_bubble.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_actions.overlay.dart';
import 'package:messages/ui/pages/conversation/widgets/reactions.sheet.dart';
import 'package:messages/ui/pages/conversation/widgets/timeline_separator.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/voice_recorder.widget.dart';
import 'package:messages/ui/providers/attachment_providers.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/providers/voice_recorder.provider.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/theme/chat_theme.widget.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';
import 'package:messages/ui/widgets/content_panel.widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Un fil de discussion : l'en-tête de l'interlocuteur, les bulles, le champ de
/// rédaction.
///
/// L'ouverture marque le fil comme lu, et le brouillon en cours est restitué
/// puis re-sauvegardé à la sortie.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({
    super.key,
    required this.threadId,
    this.revealMessageId,
  });

  final String threadId;

  /// Message sur lequel ouvrir le fil, quand on arrive de la recherche : il
  /// est amené sous les yeux et teinté le temps qu'on le repère.
  final String? revealMessageId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Capturé à l'init : `dispose` ne doit pas lire un `Ref` déjà démonté.
  late final SaveDraftUseCase _saveDraft;

  bool _draftRestored = false;

  /// Sur quel onglet le panneau des emoji et des GIF est-il déployé sous le
  /// champ — et est-il seulement déployé ?
  ///
  /// De l'état d'écran, pas de l'état d'app : il ne survit pas au fil qu'on
  /// quitte, et rien d'autre que cette page n'a à savoir qu'il est ouvert.
  ExpressionTab? _picker;

  /// Message que la recherche a désigné, tant qu'il est encore teinté.
  late String? _revealed = widget.revealMessageId;

  /// Sa clé, pour l'amener sous les yeux : elle n'existe que s'il est construit.
  final GlobalKey _revealKey = GlobalKey();

  /// Ce qui efface la teinte, une fois le message repéré.
  Timer? _fade;

  /// Le fil n'est amené sur le message qu'**une fois**, à l'ouverture : un
  /// rechargement (SMS reçu, accusé de remise) ne doit pas y ramener de force
  /// quelqu'un qui a fait défiler depuis.
  bool _revealDone = false;

  @override
  void initState() {
    super.initState();
    _saveDraft = ref.read(saveDraftUseCaseProvider);
    // Le marquage « lu » touche le stock : hors de la phase de build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  /// Amène le message désigné sous les yeux, puis efface sa teinte.
  ///
  /// En deux temps parce que la liste est bâtie à la demande : tant que le
  /// message n'est pas construit, sa clé n'a pas de contexte et il n'y a rien
  /// à faire défiler. On saute donc d'abord à sa hauteur *estimée* — le fil
  /// tient en mémoire, l'index est connu — et on ajuste à la frame suivante,
  /// quand il existe pour de bon. Quelques allers-retours suffisent, et le
  /// compteur borne le cas où le message a disparu entre-temps.
  Future<void> _reveal(ConversationTimelineDto timeline) async {
    final id = _revealed;
    if (id == null || _revealDone) return;
    _revealDone = true;

    final entries = timeline.entries;
    final index = entries.indexWhere(
      (e) => e is TimelineMessage && e.message.id == id,
    );
    if (index < 0) {
      // Le message n'est plus là : mieux vaut ne rien teindre que teindre le
      // voisin.
      if (mounted) setState(() => _revealed = null);
      return;
    }

    // `reverse: true` : le dernier message est en tête de liste.
    final fromEnd = entries.length - 1 - index;
    for (var attempt = 0; attempt < 6; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) return;

      final target = _revealKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
        break;
      }
      _scroll.jumpTo(
        (_scroll.position.maxScrollExtent * fromEnd / entries.length).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    }

    // La teinte dit « c'est celui-là » ; passé quelques secondes elle ne dit
    // plus rien et gêne la lecture. Un `Timer` retenu et non un `delayed` :
    // quitter le fil avant la fin laisserait sinon une minuterie derrière soi.
    _fade = Timer(
      const Duration(seconds: 3),
      () => setState(() => _revealed = null),
    );
  }

  @override
  void dispose() {
    // Fire-and-forget : le fil est déjà en train de disparaître, personne
    // n'attend le résultat.
    _saveDraft.execute(widget.threadId, _composer.text);
    _fade?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final changed = await ref
        .read(markConversationReadUseCaseProvider)
        .execute(widget.threadId);
    // Rouvrir un fil déjà lu ne change rien : rafraîchir la liste des fils
    // coûterait un parcours complet du stock, pendant l'animation d'ouverture.
    if (!changed || !mounted) return;
    ref.invalidate(conversationsProvider);
    ref.invalidate(unreadConversationCountProvider);
  }

  /// Le fil est rethémé **au-dessus** de tout ce qu'il peint : la barre, les
  /// bulles, le champ et les panneaux lisent alors les couleurs du fil sans
  /// rien savoir de son thème. Le `Builder` sert à ça — sans lui, `context`
  /// serait celui d'avant le `Theme`.
  @override
  Widget build(BuildContext context) {
    final conversation = ref.watch(conversationProvider(widget.threadId)).value;
    return ChatTheme(
      seed: conversation?.themeSeed,
      child: Builder(builder: _scaffold),
    );
  }

  Widget _scaffold(BuildContext context) {
    final colors = context.appColors;
    final conversationAsync = ref.watch(conversationProvider(widget.threadId));
    final timelineAsync = ref.watch(
      conversationTimelineProvider(widget.threadId),
    );
    final access = ref.watch(smsAccessControllerProvider).value;
    final canSend = access?.canCompose ?? false;

    // Le brouillon n'est restitué qu'une fois, et jamais par-dessus une saisie
    // en cours.
    final draft = ref.watch(draftProvider(widget.threadId)).value;
    if (!_draftRestored && draft != null && _composer.text.isEmpty) {
      _draftRestored = true;
      _composer.text = draft;
    }

    final conversation = conversationAsync.value;
    final attachments = ref.watch(attachmentTrayProvider(widget.threadId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _appBar(context, conversation),
      // Le fil et son champ de rédaction vivent dans le même panneau, posé sur
      // le fond pêche : c'est la mise en page de l'app d'origine.
      body: _Wallpaper(
        path: conversation?.wallpaperPath,
        child: ContentPanel(
          // Le panneau s'efface devant le fond d'écran : sans ça, la photo
          // choisie ne se verrait qu'autour du fil.
          color: conversation?.wallpaperPath == null
              ? null
              : Colors.transparent,
          child: Column(
          children: [
            Expanded(
              child: timelineAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erreur : $error')),
                data: (timeline) {
                  if (timeline.isEmpty) return const _EmptyThread();
                  // Le fil vient d'arriver : c'est le premier moment où l'on
                  // sait à quel rang se trouve le message cherché.
                  if (_revealed != null && !_revealDone) _reveal(timeline);
                  return _Timeline(
                    timeline: timeline,
                    controller: _scroll,
                    onLongPress: _onMessageAction,
                    onReactionsTap: _onReactionsTap,
                    onRetry: _resend,
                    revealedId: _revealed,
                    revealedKey: _revealKey,
                  );
                },
              ),
            ),
            // Une seule zone sûre pour tout le bas de l'écran : le champ et
            // le panneau s'y empilent, et l'encoche du bas n'est comptée
            // qu'une fois.
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AttachmentTrayBar(threadId: widget.threadId),
                  MessageComposer(
                    controller: _composer,
                    enabled: canSend,
                    onSend: _send,
                    onAttach: _onAttach,
                    onEmoji: _toggleEmoji,
                    onGallery: _onGallery,
                    emojiOpen: _picker != null,
                    onVoice: _onVoice,
                    onVoiceHold: _onVoiceHold,
                    onVoiceCancel: _voice.close,
                    onVoiceLock: _voice.lock,
                    onVoiceRelease: _voice.release,
                    hasAttachments: attachments.isNotEmpty,
                  ),
                  // Sous le champ, et non par-dessus : dans l'app d'origine le
                  // panneau pousse le fil vers le haut sans jamais masquer ce
                  // qu'on vient d'écrire. Les deux panneaux se posent au même
                  // endroit, et un seul s'y tient à la fois.
                  VoiceRecorderPanel(
                    threadId: widget.threadId,
                    onError: _onVoiceError,
                  ),
                  if (_picker != null)
                    ExpressionPicker(
                      threadId: widget.threadId,
                      controller: _composer,
                      initialTab: _picker!,
                      onPicked: _onGifPicked,
                      onError: _onGifError,
                      onClose: _closePicker,
                    ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }


  PreferredSizeWidget _appBar(
    BuildContext context,
    ConversationDto? conversation,
  ) {
    final colors = context.appColors;
    final title = conversation?.title ?? '';
    final address = conversation?.addresses.firstOrNull;

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 4,
      // La pastille et le nom forment **un seul bouton**, comme le
      // `top_app_bar_title_row` de l'app d'origine : il ouvre les détails du
      // fil. C'est le geste qu'on tente naturellement pour voir qui est en
      // face, et il ne doit pas tomber à plat.
      title: InkWell(
        key: const Key('openThreadDetails'),
        onTap: conversation == null
            ? null
            : () => context.push(AppRoutes.threadDetails(widget.threadId)),
        borderRadius: BorderRadius.circular(28),
        // Vertical seulement : l'app d'origine cale le bord gauche de son
        // bouton sur celui de la pastille, et lui donne 48 de haut pour 40 de
        // pastille.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (conversation != null) ...[
                Avatar(avatar: conversation.avatar, size: 40),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (address != null)
          IconButton(
            key: const Key('callRecipient'),
            tooltip: 'Appeler',
            icon: const Icon(Icons.call_outlined, size: 26),
            onPressed: () => _call(address),
          ),
        if (conversation != null)
          ConversationMenu(
            conversation: conversation,
            onDeleted: () => context.pop(),
          ),
      ],
    );
  }

  Future<void> _send(String body) async {
    final conversation = ref.read(conversationProvider(widget.threadId)).value;
    final recipients = conversation?.addresses ?? const <String>[];
    if (recipients.isEmpty) {
      // Un fil présent dans la liste mais sans destinataire lisible : le stock
      // système en contient, et l'utilisateur se retrouve devant un fil dans
      // lequel il ne peut pas écrire sans savoir pourquoi.
      ref
          .read(loggerProvider)
          .warn(
            'message.send_blocked',
            attrs: {'reason': 'no_recipient', 'thread.id': widget.threadId},
          );
      _announce('Destinataire inconnu pour ce fil.');
      return;
    }

    // Le champ se vide tout de suite : l'envoi est optimiste, l'état de la
    // bulle dira la suite. Le plateau, lui, n'est vidé qu'une fois l'envoi
    // accepté — c'est le contrôleur qui s'en charge.
    _composer.clear();
    try {
      await ref
          .read(attachmentTrayProvider(widget.threadId).notifier)
          .send(recipients: recipients, body: body);
    } on SmsException catch (e) {
      _composer.text = body;
      _announce(e.message);
      return;
    }
    if (!mounted) return;
    ref.invalidate(conversationTimelineProvider(widget.threadId));
    ref.invalidate(conversationsProvider);
    _scrollToBottom();
  }

  Future<void> _resend(MessageDto message) async {
    try {
      await ref.read(resendMessageUseCaseProvider).execute(message.id);
    } on SmsException catch (e) {
      _announce(e.message);
      return;
    }
    if (!mounted) return;
    ref.invalidate(conversationTimelineProvider(widget.threadId));
  }

  /// Qui a posé quoi : un appui sur une pastille de réaction.
  Future<void> _onReactionsTap(MessageDto message) =>
      ReactionsSheet.show(context, message);

  Future<void> _onMessageAction(TimelineMessage entry, Rect anchor) async {
    final message = entry.message;
    final choice = await MessageActionsOverlay.show(
      context,
      entry: entry,
      anchor: anchor,
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case MessageReactionChoice(:final emoji):
        await _react(message, emoji);
      case MessageActionChoice(action: MessageAction.copy):
        await MessageActionsOverlay.copy(message);
        _announce('Message copié');
      case MessageActionChoice(action: MessageAction.forward):
        await context.push(AppRoutes.newConversation, extra: message.body);
      case MessageActionChoice(action: MessageAction.delete):
        await ref.read(deleteMessageUseCaseProvider).execute(message.id);
        if (!mounted) return;
        ref.invalidate(conversationTimelineProvider(widget.threadId));
        ref.invalidate(conversationsProvider);
      case MessageActionChoice(action: MessageAction.resend):
        await _resend(message);
      case MessageActionChoice(action: MessageAction.details):
        await MessageActionsOverlay.showDetails(context, message);
    }
  }

  /// Réagir envoie un SMS — et le retirer en envoie un second.
  ///
  /// Rien de tout cela n'est gratuit ni instantané : la pastille n'apparaît
  /// qu'une fois le message déposé et relu du stock, comme n'importe quel
  /// envoi. Toucher l'emoji qu'on a déjà posé le retire.
  Future<void> _react(MessageDto message, String emoji) async {
    final conversation = ref.read(conversationProvider(widget.threadId)).value;
    final recipients = conversation?.addresses ?? const <String>[];
    if (recipients.isEmpty) {
      _announce('Destinataire inconnu pour ce fil.');
      return;
    }

    try {
      await ref
          .read(reactToMessageUseCaseProvider)
          .execute(
            messageId: message.id,
            recipients: recipients,
            emoji: emoji,
            remove: message.myReaction == emoji,
          );
    } on SmsException catch (e) {
      _announce(e.message);
      return;
    }
    if (!mounted) return;
    ref.invalidate(conversationTimelineProvider(widget.threadId));
    ref.invalidate(conversationsProvider);
  }

  VoiceRecorder get _voice =>
      ref.read(voiceRecorderProvider(widget.threadId).notifier);

  /// Ouvre le panneau d'enregistrement, sans encore ouvrir le micro : la
  /// permission se demandera au geste suivant, là où l'utilisateur comprend
  /// pourquoi on la lui demande.
  void _onVoice() => _voice.open();

  /// L'appui **maintenu** sur le disque : ici, au contraire, le micro s'ouvre
  /// dans le même geste — c'est tout l'intérêt du geste.
  ///
  /// Rend `false` quand il ne s'est pas ouvert, pour que le champ n'aille pas
  /// peindre une barre d'enregistrement devant un micro fermé.
  Future<bool> _onVoiceHold() async {
    try {
      return await _voice.hold();
    } on SmsException catch (e) {
      _announce(e.message);
      return false;
    }
  }

  /// Le micro refusé, ou l'enregistrement qui ne démarre pas. Les deux laissent
  /// l'utilisateur devant un panneau qui ne fait rien : le silence passerait
  /// pour une panne.
  void _onVoiceError(Object error) {
    if (error is SmsException) {
      _announce(error.message);
      return;
    }
    _announce('L\'enregistrement n\'a pas pu démarrer.');
  }

  /// Ouvre le panneau des sources, puis pose sur le plateau ce qui en revient.
  ///
  /// Une sélection annulée ne dit rien : c'est un non-événement. Un refus du
  /// domaine (plateau trop lourd, trop de pièces) se dit, lui, tout de suite —
  /// c'est le seul moment où l'utilisateur peut encore y remédier.
  Future<void> _onAttach() async {
    final choice = await AttachmentSheet.show(context);
    if (choice == null || !mounted) return;

    // Le GIF n'ouvre pas d'écran du système : il déploie son catalogue sous le
    // champ. C'est le seul choix du panneau qui ne passe pas par le sélecteur.
    final source = choice.source;
    if (source == null) {
      _openPicker(ExpressionTab.gif);
      return;
    }

    await _addFrom(source);
  }

  /// Le bouton galerie du champ : la même source, sans le détour par le
  /// panneau. C'est ce que fait l'app d'origine, où ce raccourci ouvre
  /// directement le sélecteur de photos.
  Future<void> _onGallery() => _addFrom(AttachmentSource.gallery);

  Future<void> _addFrom(AttachmentSource source) async {
    try {
      await ref
          .read(attachmentTrayProvider(widget.threadId).notifier)
          .add(source);
    } on SmsException catch (e) {
      _announce(e.message);
    }
  }

  /// Le bouton emoji du champ est un **interrupteur** : il ouvre le panneau,
  /// et le referme. C'est ce que fait l'app d'origine, et c'est le geste le
  /// plus court pour récupérer le clavier — la main est déjà là.
  void _toggleEmoji() {
    if (_picker != null) {
      _closePicker();
      return;
    }
    _openPicker(ExpressionTab.emoji);
  }

  void _openPicker(ExpressionTab tab) {
    // Deux panneaux au même endroit se recouvriraient : celui du vocal se
    // referme d'abord. Et le clavier avec, sans quoi le panneau s'ouvrirait
    // derrière lui.
    ref.read(voiceRecorderProvider(widget.threadId).notifier).close();
    FocusScope.of(context).unfocus();
    setState(() => _picker = tab);
  }

  void _closePicker() => setState(() => _picker = null);

  /// Le GIF est téléchargé : il rejoint le plateau comme n'importe quelle
  /// pièce jointe déjà à la bonne taille.
  Future<void> _onGifPicked(AttachmentDraft draft) async {
    try {
      await ref
          .read(attachmentTrayProvider(widget.threadId).notifier)
          .addReady(draft);
    } on SmsException catch (e) {
      _announce(e.message);
    }
  }

  /// Catalogue injoignable, GIF trop lourd pour le MMS : dans les deux cas
  /// l'utilisateur vient de toucher une vignette et n'a rien vu arriver. Le
  /// silence passerait pour une panne.
  void _onGifError(Object error) {
    if (error is SmsException) {
      _announce(error.message);
      return;
    }
    _announce('Ce GIF n\'a pas pu être ajouté.');
  }

  Future<void> _call(String address) async {
    final uri = Uri(scheme: 'tel', path: address);
    if (!await launchUrl(uri)) {
      // Aucune exception ne remonte d'un `launchUrl` qui rend `false` : sans
      // ce log, un téléphone sans application d'appel ne laisse aucune trace.
      await ref.read(loggerProvider).warn('call.launch_failed');
      _announce('Aucune application d\'appel disponible.');
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    // La liste est inversée : le bas, c'est l'offset zéro.
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _announce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Le fil, du plus récent (en bas) au plus ancien. `reverse: true` fait
/// démarrer la vue sur le dernier message et garde la position quand le clavier
/// s'ouvre.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.timeline,
    required this.controller,
    required this.onLongPress,
    required this.onReactionsTap,
    required this.onRetry,
    this.revealedId,
    this.revealedKey,
  });

  final ConversationTimelineDto timeline;
  final ScrollController controller;
  final void Function(TimelineMessage entry, Rect anchor) onLongPress;
  final ValueChanged<MessageDto> onReactionsTap;
  final ValueChanged<MessageDto> onRetry;

  /// Message désigné par la recherche, teinté le temps qu'on le repère.
  final String? revealedId;
  final GlobalKey? revealedKey;

  @override
  Widget build(BuildContext context) {
    final entries = timeline.entries;

    return ListView.builder(
      key: const Key('timeline'),
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return switch (entry) {
          TimelineSeparator(:final at) => TimelineSeparatorLabel(at: at),
          TimelineMessage() => _maybeRevealed(
            context,
            entry,
            MessageBubble(
              entry: entry,
              onLongPress: (anchor) => onLongPress(entry, anchor),
              onReactionsTap: () => onReactionsTap(entry.message),
              onRetry: entry.message.status.hasFailed
                  ? () => onRetry(entry.message)
                  : null,
            ),
          ),
        };
      },
    );
  }

  /// La bande teintée derrière le message que la recherche a désigné.
  ///
  /// Sur toute la largeur et non sur la bulle : c'est la ligne qu'on cherche
  /// du regard en arrivant, pas la forme du message.
  Widget _maybeRevealed(
    BuildContext context,
    TimelineMessage entry,
    Widget bubble,
  ) {
    if (entry.message.id != revealedId) return bubble;
    return Container(
      key: revealedKey,
      color: context.appColors.accentSoft.withValues(alpha: 0.55),
      child: bubble,
    );
  }
}

/// La photo choisie pour le fil, sous les bulles.
///
/// Un voile la couvre à moitié : une photo laissée nue rendrait illisibles les
/// séparateurs de date et les horodatages, qui sont écrits en gris sur le fond
/// et n'ont pas de bulle pour les porter.
class _Wallpaper extends StatelessWidget {
  const _Wallpaper({required this.path, required this.child});

  final String? path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final file = path;
    if (file == null) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(file),
          fit: BoxFit.cover,
          // La photo peut avoir été supprimée depuis : le fil se peint alors
          // comme s'il n'y en avait jamais eu.
          errorBuilder: (context, _, _) =>
              ColoredBox(color: context.appColors.surface),
        ),
        ColoredBox(
          color: context.appColors.surface.withValues(alpha: 0.55),
        ),
        child,
      ],
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Aucun message pour l\'instant.\nÉcrivez le premier.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }
}
