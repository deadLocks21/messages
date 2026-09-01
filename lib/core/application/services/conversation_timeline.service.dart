import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/application/dtos/message.dto.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/model/reaction_fold.dart';
import 'package:messages/core/domain/services/message.repository.dart';

/// Transforme la suite plate des messages d'un fil en ce que l'écran affiche :
/// des salves de bulles séparées par des repères temporels.
///
/// Deux règles, calquées sur Google Messages :
///
/// - **Séparateur** dès que le jour change, ou après plus d'une heure de
///   silence. Le premier message en porte toujours un.
/// - **Groupement** des messages consécutifs du même interlocuteur espacés de
///   moins de cinq minutes : seule la dernière bulle du groupe a un coin
///   « queue », seule la première porte le nom en conversation de groupe.
///
/// C'est aussi ici que les **réactions** cessent d'être des messages : le stock
/// n'en connaît pas, il ne connaît que les SMS qui les transportent. Le repli
/// (`ReactionFolder`) les retire du fil et les accroche aux bulles qu'elles
/// visent — tout le reste du service travaille ensuite sur ce qu'il en reste.
class ConversationTimelineService {
  final MessageRepository _messages;
  final ContactDirectoryService _directory;

  const ConversationTimelineService({
    required MessageRepository messages,
    required ContactDirectoryService directory,
  }) : _messages = messages,
       _directory = directory;

  /// Silence au-delà duquel on réaffiche l'heure.
  static const separatorGap = Duration(hours: 1);

  /// Écart max entre deux bulles d'une même salve.
  static const groupingGap = Duration(minutes: 5);

  Future<ConversationTimelineDto> build(
    String threadId, {
    int limit = 500,
    bool foldReactions = true,
  }) async {
    final stored = await _messages.listForThread(threadId, limit: limit);
    if (stored.isEmpty) {
      return ConversationTimelineDto(threadId: threadId, entries: const []);
    }

    final folded = ReactionFolder.fold(stored, enabled: foldReactions);
    final messages = folded.messages;
    if (messages.isEmpty) {
      return ConversationTimelineDto(threadId: threadId, entries: const []);
    }

    final directory = await _directory.load();
    final isGroup =
        messages.map((m) => m.address.key).toSet().length > 1;
    // Sur les bulles restantes, pas sur le stock : une réaction repliée est le
    // dernier message envoyé du fil, et l'état « Envoyé » disparaîtrait avec
    // elle.
    final lastOutgoingId = messages
        .where((m) => m.isOutgoing)
        .map((m) => m.id)
        .lastOrNull;

    final entries = <TimelineEntry>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final previous = i == 0 ? null : messages[i - 1];
      final next = i == messages.length - 1 ? null : messages[i + 1];

      final startsSection = previous == null || _separates(previous, message);
      if (startsSection) entries.add(TimelineSeparator(message.sentAt));

      entries.add(
        TimelineMessage(
          message: MessageDto.fromDomain(
            message,
            senderName: isGroup && !message.isOutgoing
                ? directory.nameFor(message.address)
                : null,
            reactions: folded.on(message.id),
          ),
          isFirstOfGroup: startsSection || !_groups(previous, message),
          isLastOfGroup: next == null ||
              _separates(message, next) ||
              !_groups(message, next),
          showStatus: message.id == lastOutgoingId,
        ),
      );
    }

    return ConversationTimelineDto(threadId: threadId, entries: entries);
  }

  bool _separates(Message a, Message b) {
    final sameDay =
        a.sentAt.year == b.sentAt.year &&
        a.sentAt.month == b.sentAt.month &&
        a.sentAt.day == b.sentAt.day;
    return !sameDay || b.sentAt.difference(a.sentAt) > separatorGap;
  }

  bool _groups(Message? previous, Message current) {
    if (previous == null) return false;
    if (previous.direction != current.direction) return false;
    if (previous.address != current.address) return false;
    // Un échec isolé garde sa propre bulle : son état doit rester lisible.
    if (previous.status == MessageStatus.failed ||
        current.status == MessageStatus.failed) {
      return false;
    }
    return current.sentAt.difference(previous.sentAt) <= groupingGap;
  }
}
