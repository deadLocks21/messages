import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';

/// Résultat d'une recherche : les fils dont le nom correspond, puis les
/// messages dont le texte correspond (comme Google Messages).
class SearchResultsDto {
  final String query;
  final List<ConversationDto> conversations;
  final List<MessageHitDto> messages;

  const SearchResultsDto({
    required this.query,
    required this.conversations,
    required this.messages,
  });

  static const empty = SearchResultsDto(
    query: '',
    conversations: [],
    messages: [],
  );

  bool get isEmpty => conversations.isEmpty && messages.isEmpty;
}

/// Un message trouvé, accompagné du nom de son fil pour être situable.
class MessageHitDto {
  final MessageDto message;
  final String conversationTitle;

  const MessageHitDto({required this.message, required this.conversationTitle});
}
