import 'package:messages/core/domain/services/draft.repository.dart';

/// Enregistre (ou efface) le brouillon d'un fil. Appelé quand on quitte un fil
/// sans avoir envoyé.
class SaveDraftUseCase {
  final DraftRepository _drafts;

  const SaveDraftUseCase(this._drafts);

  Future<void> execute(String threadId, String body) {
    if (threadId.isEmpty) return Future.value();
    return _drafts.save(threadId, body.trim());
  }
}
