import 'package:messages/core/domain/services/emoji_history.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emoji récents persistés dans `shared_preferences`, comme une simple liste
/// de chaînes — il n'y a rien à encoder, un emoji *est* une chaîne.
class SharedPreferencesEmojiHistoryRepository
    implements EmojiHistoryRepository {
  const SharedPreferencesEmojiHistoryRepository();

  static const _key = 'messages.emoji.recents';

  @override
  Future<List<String>> recents() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];

  @override
  Future<void> remember(String character) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = [
      character,
      ...(prefs.getStringList(_key) ?? const []).where((e) => e != character),
    ];
    await prefs.setStringList(
      _key,
      recents.take(EmojiHistoryRepository.maxCount).toList(),
    );
  }
}
