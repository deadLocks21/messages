import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/usecases/save_draft.usecase.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_sheet.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/attachment_tray.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/conversation_menu.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_bubble.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_composer.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/message_options.sheet.dart';
import 'package:messages/ui/pages/conversation/widgets/timeline_separator.widget.dart';
import 'package:messages/ui/pages/conversation/widgets/voice_recorder.widget.dart';
import 'package:messages/ui/providers/attachment_providers.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/providers/voice_recorder.provider.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_colors.dart';
import 'package:messages/ui/widgets/avatar.widget.dart';
import 'package:messages/ui/widgets/content_panel.widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Un fil de discussion : l'en-tête de l'interlocuteur, les bulles, le champ de
/// rédaction.
///
/// L'ouverture marque le fil comme lu, et le brouillon en cours est restitué
/// puis re-sauvegardé à la sortie.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Capturé à l'init : `dispose` ne doit pas lire un `Ref` déjà démonté.
  late final SaveDraftUseCase _saveDraft;

  bool _draftRestored = false;

  @override
  void initState() {
    super.initState();
    _saveDraft = ref.read(saveDraftUseCaseProvider);
    // Le marquage « lu » touche le stock : hors de la phase de build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    // Fire-and-forget : le fil est déjà en train de disparaître, personne
    // n'attend le résultat.
    _saveDraft.execute(widget.threadId, _composer.text);
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

  @override
  Widget build(BuildContext context) {
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
      body: ContentPanel(
        child: Column(
          children: [
            Expanded(
              child: timelineAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Erreur : $error')),
                data: (timeline) => timeline.isEmpty
                    ? const _EmptyThread()
                    : _Timeline(
                        timeline: timeline,
                        controller: _scroll,
                        onLongPress: _onMessageAction,
                        onRetry: _resend,
                      ),
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
                    onVoice: _onVoice,
                    onVoiceHold: _onVoiceHold,
                    onVoiceCancel: _voice.close,
                    onVoiceLock: _voice.lock,
                    onVoiceRelease: _voice.release,
                    hasAttachments: attachments.isNotEmpty,
                  ),
                  // Sous le champ, et non par-dessus : dans l'app d'origine le
                  // panneau pousse le fil vers le haut sans jamais masquer ce
                  // qu'on vient d'écrire.
                  VoiceRecorderPanel(
                    threadId: widget.threadId,
                    onError: _onVoiceError,
                  ),
                ],
              ),
            ),
          ],
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
      title: Row(
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

  Future<void> _onMessageAction(MessageDto message) async {
    final action = await MessageOptionsSheet.show(context, message);
    if (action == null || !mounted) return;

    switch (action) {
      case MessageAction.copy:
        await MessageOptionsSheet.copy(message);
        _announce('Message copié');
      case MessageAction.forward:
        await context.push(AppRoutes.newConversation, extra: message.body);
      case MessageAction.delete:
        await ref.read(deleteMessageUseCaseProvider).execute(message.id);
        if (!mounted) return;
        ref.invalidate(conversationTimelineProvider(widget.threadId));
        ref.invalidate(conversationsProvider);
      case MessageAction.resend:
        await _resend(message);
    }
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
    final source = await AttachmentSheet.show(context);
    if (source == null || !mounted) return;
    try {
      await ref
          .read(attachmentTrayProvider(widget.threadId).notifier)
          .add(source);
    } on SmsException catch (e) {
      _announce(e.message);
    }
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
    required this.onRetry,
  });

  final ConversationTimelineDto timeline;
  final ScrollController controller;
  final ValueChanged<MessageDto> onLongPress;
  final ValueChanged<MessageDto> onRetry;

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
          TimelineMessage() => MessageBubble(
            entry: entry,
            onLongPress: () => onLongPress(entry.message),
            onRetry: entry.message.status.hasFailed
                ? () => onRetry(entry.message)
                : null,
          ),
        };
      },
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
