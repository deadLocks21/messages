import 'package:messages/core/domain/services/draft.repository.dart';

/// Brouillons en mémoire.
class InMemoryDraftRepository implements DraftRepository {
  final Map<String, String> _byThreadId = {};

  @override
  Future<Map<String, String>> listAll() async => Map.unmodifiable(_byThreadId);

  @override
  Future<String?> get(String threadId) async => _byThreadId[threadId];

  @override
  Future<void> save(String threadId, String body) async {
    if (body.trim().isEmpty) {
      _byThreadId.remove(threadId);
      return;
    }
    _byThreadId[threadId] = body;
  }

  @override
  Future<void> remove(String threadId) async => _byThreadId.remove(threadId);
}
