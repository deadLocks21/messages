import 'package:messages/core/domain/services/reaction_preferences.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglage d'affichage des réactions, persisté dans `shared_preferences`.
class SharedPreferencesReactionPreferencesRepository
    implements ReactionPreferencesRepository {
  static const _key = 'messages.fold_reactions';

  const SharedPreferencesReactionPreferencesRepository();

  @override
  Future<bool> foldsReactions() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? true;

  @override
  Future<void> setFoldsReactions(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_key, value);
  }
}
