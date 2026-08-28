import 'package:messages/core/domain/services/attachment_opener.service.dart';

/// [AttachmentOpener] simulé : il n'ouvre rien, il note.
///
/// Hors Android il n'y a pas d'application à qui passer un PDF. La doublure
/// retient ce qu'on lui a demandé d'ouvrir — c'est ce que les tests vérifient —
/// et [canOpen] permet de rejouer le cas qui compte : l'appareil où aucune
/// application ne sait le faire.
class InMemoryAttachmentOpener implements AttachmentOpener {
  final List<String> opened = [];

  /// Ce que répondra la prochaine ouverture.
  bool canOpen;

  InMemoryAttachmentOpener({this.canOpen = true});

  @override
  Future<bool> open(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  }) async {
    opened.add(attachmentId);
    return canOpen;
  }
}
