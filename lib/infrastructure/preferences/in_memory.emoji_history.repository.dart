import 'package:messages/core/domain/services/emoji_history.repository.dart';

/// Emoji récents en mémoire : la démonstration et les tests, où ils ne
/// survivent pas au processus.
class InMemoryEmojiHistoryRepository implements EmojiHistoryRepository {
  final List<String> _recents;

  InMemoryEmojiHistoryRepository({List<String> recents = const []})
    : _recents = [...recents];

  @override
  Future<List<String>> recents() async => List.unmodifiable(_recents);

  @override
  Future<void> remember(String character) async {
    _recents
      ..remove(character)
      ..insert(0, character);
    if (_recents.length > EmojiHistoryRepository.maxCount) {
      _recents.removeRange(EmojiHistoryRepository.maxCount, _recents.length);
    }
  }
}
