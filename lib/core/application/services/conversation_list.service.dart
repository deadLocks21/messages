import 'package:messages/core/application/dtos/avatar.dto.dart';
import 'package:messages/core/application/dtos/attachment.dto.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/services/avatar_palette.service.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/core/domain/services/blocked_numbers.repository.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/domain/services/draft.repository.dart';

/// Assemble la liste des conversations telle qu'elle s'affiche : fils du stock
/// SMS + noms du carnet d'adresses + réglages locaux (épinglé/archivé/sourdine)
/// + brouillons.
///
/// C'est le seul endroit qui connaît l'ordre d'affichage : épinglés d'abord,
/// puis du plus récent au plus ancien.
class ConversationListService {
  final ConversationRepository _conversations;
  final ContactDirectoryService _directory;
  final ConversationPreferencesRepository _preferences;
  final DraftRepository _drafts;
  final BlockedNumbersRepository _blocked;

  const ConversationListService({
    required ConversationRepository conversations,
    required ContactDirectoryService directory,
    required ConversationPreferencesRepository preferences,
    required DraftRepository drafts,
    required BlockedNumbersRepository blocked,
  }) : _conversations = conversations,
       _directory = directory,
       _preferences = preferences,
       _drafts = drafts,
       _blocked = blocked;

  Future<List<ConversationDto>> list({
    ConversationFilter filter = ConversationFilter.all,
  }) async {
    final conversations = await _conversations.listAll();
    final directory = await _directory.load();
    final preferences = {
      for (final p in await _preferences.listAll()) p.threadId: p,
    };
    final drafts = await _drafts.listAll();
    // Les clés et non les adresses : bloquer `+33612345678` doit sortir de la
    // liste le fil ouvert sur `0612345678`.
    final blocked = {for (final a in await _blocked.listAll()) a.key};

    final items = conversations
        .map(
          (c) => _toDto(
            c,
            directory,
            preferences[c.id] ?? ConversationPreference.none(c.id),
            drafts[c.id],
            isBlocked: c.recipients.any((a) => blocked.contains(a.key)),
          ),
        )
        .where((dto) => _matches(dto, filter))
        .toList();

    items.sort(_byPinnedThenDate);
    return items;
  }

  /// Un fil précis, pour l'en-tête de la page de conversation.
  ///
  /// Un fil **sans message** n'a pas de résumé — un résumé se construit à
  /// partir de ses messages, et celui qu'on vient de créer depuis le sélecteur
  /// n'en a aucun. Ses destinataires, eux, existent : sans ce repli, la
  /// conversation qu'on vient d'ouvrir s'affiche sans nom et refuse le premier
  /// envoi, faute de savoir à qui.
  Future<ConversationDto?> byId(String threadId) async {
    final conversation = await _conversations.getById(threadId);
    if (conversation == null) {
      final recipients = await _conversations.recipientsOf(threadId);
      if (recipients.isEmpty) return null;
      return (await previewFor(recipients)).copyWith(threadId: threadId);
    }
    final directory = await _directory.load();
    final preferences = await _preferences.listAll();
    final blocked = {for (final a in await _blocked.listAll()) a.key};
    return _toDto(
      conversation,
      directory,
      preferences
              .where((p) => p.threadId == threadId)
              .firstOrNull ??
          ConversationPreference.none(threadId),
      await _drafts.get(threadId),
      isBlocked: conversation.recipients.any((a) => blocked.contains(a.key)),
    );
  }

  /// En-tête d'un fil qui n'existe pas encore : on connaît les destinataires,
  /// pas le `thread_id`. Permet d'afficher « Alice » dès l'écran de rédaction.
  Future<ConversationDto> previewFor(List<Address> recipients) async {
    final directory = await _directory.load();
    return ConversationDto(
      threadId: '',
      title: directory.titleFor(recipients),
      snippet: '',
      lastMessageAt: DateTime.now(),
      addresses: recipients.map((a) => a.raw).toList(),
      avatar: _avatarFor(recipients, directory, isGroup: recipients.length > 1),
      isGroup: recipients.length > 1,
    );
  }

  ConversationDto _toDto(
    Conversation conversation,
    ContactDirectory directory,
    ConversationPreference preference,
    String? draft, {
    bool isBlocked = false,
  }) {
    return ConversationDto(
      threadId: conversation.id,
      title: directory.titleFor(conversation.recipients),
      snippet: _snippetFor(conversation),
      lastMessageAt: conversation.lastMessageAt,
      unreadCount: conversation.unreadCount,
      isPinned: preference.pinned,
      isArchived: preference.archived,
      isMuted: preference.muted,
      isBlocked: isBlocked,
      snoozedUntil: preference.snoozedUntil,
      themeSeed: preference.themeSeed,
      wallpaperPath: preference.wallpaperPath,
      isSilenced: preference.isSilencedAt(DateTime.now()),
      isGroup: conversation.isGroup,
      draft: draft,
      addresses: conversation.recipients.map((a) => a.raw).toList(),
      avatar: _avatarFor(
        conversation.recipients,
        directory,
        isGroup: conversation.isGroup,
      ),
    );
  }

  /// Le résumé affiché en liste.
  ///
  /// Un MMS sans légende n'a pas de texte à montrer : on le nomme par sa pièce
  /// jointe (« Photo »), comme l'app d'origine. Avec légende, le libellé
  /// précède le texte.
  ///
  /// Un fil dont le dernier message est une **réaction** afficherait, lui, la
  /// phrase anglaise qui la transporte (`Liked “…”`) : c'est ce que le stock
  /// contient, et c'est justement ce qu'on ne veut plus montrer.
  String _snippetFor(Conversation conversation) {
    final reaction = ReactionCodec.summarize(conversation.snippet);
    if (reaction != null) return reaction;

    final kind = conversation.lastAttachmentKind;
    if (kind == null) return conversation.snippet;
    final label = AttachmentDto.previewLabelFor(kind);
    return conversation.snippet.isEmpty
        ? label
        : '$label · ${conversation.snippet}';
  }

  AvatarDto _avatarFor(
    List<Address> recipients,
    ContactDirectory directory, {
    required bool isGroup,
  }) {
    final seed = directory.colorSeedFor(recipients);
    final contact = recipients.isEmpty ? null : directory.lookup(recipients.first);
    return AvatarDto(
      initial: contact?.initial ?? _initialOf(recipients),
      colorSlot: AvatarPaletteService.slotFor(seed),
      photo: isGroup ? null : contact?.photo,
      isGroup: isGroup,
    );
  }

  /// Sans contact, seul un expéditeur nommé (« ORANGE ») donne une initiale ;
  /// un numéro reste une pastille à icône.
  String _initialOf(List<Address> recipients) {
    if (recipients.isEmpty) return '';
    final address = recipients.first;
    if (!address.isAlphanumeric) return '';
    return address.raw.trim().substring(0, 1).toUpperCase();
  }

  /// Un fil bloqué sort de partout sauf de « Spam et bloqués » : ses messages
  /// restent dans le stock, mais l'app cesse de les mettre sous les yeux.
  bool _matches(ConversationDto dto, ConversationFilter filter) => switch (filter) {
    ConversationFilter.all => !dto.isArchived && !dto.isBlocked,
    ConversationFilter.unread =>
      !dto.isArchived && !dto.isBlocked && dto.hasUnread,
    ConversationFilter.archived => dto.isArchived && !dto.isBlocked,
    ConversationFilter.blocked => dto.isBlocked,
  };

  int _byPinnedThenDate(ConversationDto a, ConversationDto b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    return b.lastMessageAt.compareTo(a.lastMessageAt);
  }
}
