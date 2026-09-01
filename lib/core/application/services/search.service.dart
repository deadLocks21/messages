import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Recherche unifiée : les fils dont le nom (ou le numéro) correspond, puis les
/// messages dont le texte correspond — dans cet ordre, comme Google Messages.
class SearchService {
  final ConversationListService _conversations;
  final MessageRepository _messages;

  const SearchService({
    required ConversationListService conversations,
    required MessageRepository messages,
  }) : _conversations = conversations,
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

  bool _matchesConversation(ConversationDto c, String needle, String digits) {
    if (c.title.toLowerCase().contains(needle)) return true;
    if (digits.isEmpty) return false;
    return c.addresses.any(
      (a) => Address.significantDigits(a).contains(digits),
    );
  }
}
