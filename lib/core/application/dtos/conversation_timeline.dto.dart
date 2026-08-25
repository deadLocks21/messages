import 'package:messages/core/application/dtos/message.dto.dart';

/// Fil déroulé d'une conversation : les messages, entrecoupés des séparateurs
/// de date, avec les indications de groupement dont l'UI a besoin pour arrondir
/// correctement les coins des bulles.
class ConversationTimelineDto {
  final String threadId;
  final List<TimelineEntry> entries;

  const ConversationTimelineDto({required this.threadId, required this.entries});

  static const empty = ConversationTimelineDto(threadId: '', entries: []);

  bool get isEmpty => entries.isEmpty;
}

/// Élément du fil. Classe scellée : l'UI en fait un `switch` exhaustif.
sealed class TimelineEntry {
  const TimelineEntry();
}

/// Séparateur temporel centré (« Aujourd'hui, 10:32 »).
class TimelineSeparator extends TimelineEntry {
  final DateTime at;
  const TimelineSeparator(this.at);
}

/// Une bulle, avec sa position dans son groupe de messages consécutifs.
class TimelineMessage extends TimelineEntry {
  final MessageDto message;

  /// Première/dernière bulle d'une salve du même interlocuteur : détermine les
  /// coins arrondis et l'affichage du nom (en groupe).
  final bool isFirstOfGroup;
  final bool isLastOfGroup;

  /// Dernière bulle envoyée du fil : la seule qui porte son état.
  final bool showStatus;

  const TimelineMessage({
    required this.message,
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
    this.showStatus = false,
  });
}
