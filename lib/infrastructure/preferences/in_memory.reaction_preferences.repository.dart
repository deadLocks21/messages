import 'package:messages/core/domain/services/reaction_preferences.repository.dart';

/// Réglage non persisté (tests, plateformes sans stockage).
class InMemoryReactionPreferencesRepository
    implements ReactionPreferencesRepository {
  bool _folds;

  InMemoryReactionPreferencesRepository({bool folds = true}) : _folds = folds;

  @override
  Future<bool> foldsReactions() async => _folds;

  @override
  Future<void> setFoldsReactions(bool value) async => _folds = value;
}
