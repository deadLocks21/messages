import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Recherche unifiée : les fils dont le nom (ou le numéro) correspond, puis les
/// messages dont le texte correspond — dans cet ordre, comme Google Messages.
class SearchService {
  final ConversationListService _conversations;
  final ContactDirectoryService _directory;
  final MessageRepository _messages;

  const SearchService({
    required ConversationListService conversations,
    required ContactDirectoryService directory,
    required MessageRepository messages,
  }) : _conversations = conversations,
       _directory = directory,
       _messages = messages;

  /// Longueur en deçà de laquelle on ne cherche pas : un caractère ramènerait
  /// tout le stock pour rien.
  static const minQueryLength = 2;

  static const messageLimit = 50;

  Future<SearchResultsDto> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < minQueryLength) return SearchResultsDto.empty;

    final needle = query.toLowerCase();
    final digits = Address.significantDigits(query);

    // Les archivées comprises : on cherche dans tout le stock, pas dans l'onglet
    // courant.
    final all = [
      ...await _conversations.list(),
      ...await _conversations.list(filter: ConversationFilter.archived),
    ];
    final byThreadId = {for (final c in all) c.threadId: c};

    final conversations = all
        .where((c) => _matchesConversation(c, needle, digits))
        .toList();

    final messages = await _messages.search(query, limit: messageLimit);
    final hits = messages
        // Les réactions sont dans le stock comme les autres messages : sans ce
        // filtre, chercher « demain » ramènerait le message *et* le `Liked
        // “demain ?”` qui l'a suivi. Personne n'a écrit cette phrase, et elle
        // n'est un résultat pour personne.
        .where((m) => ReactionCodec.decode(m.body) == null)
        .map(
          (m) => MessageHitDto(
            message: MessageDto.fromDomain(m),
            conversationTitle:
                byThreadId[m.threadId]?.title ?? m.address.display,
          ),
        )
        .toList();

    return SearchResultsDto(
      query: query,
      conversations: conversations,
      messages: hits,
    );
  }

  /// Chercher **dans un seul fil**. Ce n'est pas la même question que la
  /// recherche globale : le fil est connu, c'est le message qu'on cherche —
  /// d'où une liste de messages nue, sans les fils que l'autre écran propose
  /// d'abord.
  ///
  /// Le filtre par fil est passé au stock, pas appliqué au retour : chercher
  /// « ok » dans une conversation ne doit pas commencer par remonter les mille
  /// « ok » de toutes les autres.
  Future<List<MessageHitDto>> searchInThread(
    String threadId,
    String rawQuery,
  ) async {
    final query = rawQuery.trim();
    if (query.length < minQueryLength) return const [];

    final messages = await _messages.search(
      query,
      limit: messageLimit,
      threadId: threadId,
    );
    final directory = await _directory.load();

    return messages
        .where((m) => ReactionCodec.decode(m.body) == null)
        .map(
          (m) => MessageHitDto(
            message: MessageDto.fromDomain(m),
            // Dans un fil, la première ligne ne peut plus dire *où* le message
            // a été écrit — tout vient du même endroit. Elle dit donc **qui**
            // l'a écrit, ce qui est la seule chose qui distingue deux lignes.
            conversationTitle: m.direction == MessageDirection.outgoing
                ? 'Vous'
                : directory.nameFor(m.address),
          ),
        )
        .toList();
  }

  bool _matchesConversation(ConversationDto c, String needle, String digits) {
    if (c.title.toLowerCase().contains(needle)) return true;
    if (digits.isEmpty) return false;
    return c.addresses.any(
      (a) => Address.significantDigits(a).contains(digits),
    );
  }
}
