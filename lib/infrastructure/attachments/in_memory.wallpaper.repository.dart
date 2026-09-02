import 'package:messages/core/domain/services/wallpaper.repository.dart';

/// Fond d'écran simulé : rien n'est copié, l'URI choisie fait office de chemin.
class InMemoryWallpaperRepository implements WallpaperRepository {
  /// Ce qui a été « rangé », par fil.
  final Map<String, String> saved = {};

  /// Simule une image illisible.
  bool available = true;

  @override
  Future<String?> save({required String threadId, required String uri}) async {
    if (!available) return null;
    return saved[threadId] = uri;
  }
}
