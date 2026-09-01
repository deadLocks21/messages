import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reaction_providers.g.dart';

/// Le repli des réactions est-il actif ? Persisté derrière son port.
///
/// Le couper ne perd rien : les réactions redeviennent les messages qu'elles
/// n'ont jamais cessé d'être dans le stock — `Liked “Bonjour”`, en toutes
/// lettres. C'est exactement ce qu'il faut voir quand on cherche à comprendre
/// ce qu'un correspondant a réellement envoyé.
@Riverpod(keepAlive: true)
class ReactionFoldingController extends _$ReactionFoldingController {
  @override
  Future<bool> build() =>
      ref.watch(reactionPreferencesRepositoryProvider).foldsReactions();

  Future<void> set(bool value) async {
    await ref.read(reactionPreferencesRepositoryProvider).setFoldsReactions(value);
    state = AsyncData(value);
  }
}
