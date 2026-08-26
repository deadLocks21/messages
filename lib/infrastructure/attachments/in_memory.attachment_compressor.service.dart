import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/services/attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/sample_image.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';
import 'package:uuid/uuid.dart';

/// Compresseur simulé, mais qui **compresse vraiment**.
///
/// Il ne se contente pas d'annoncer une taille plus petite : il régénère une
/// image réellement plus petite et la dépose dans le stock simulé. Les tests
/// vérifient donc la même chose que sur téléphone — que le plateau finit sous
/// le budget, avec des octets qui existent.
///
/// La réduction suit la même logique que côté Android : on rétrécit tant qu'on
/// dépasse la cible, et on renonce en dessous d'un plancher.
class InMemoryAttachmentCompressor implements AttachmentCompressor {
  final InMemorySmsStore _store;
  final Uuid _uuid;

  /// En dessous, l'image ne vaudrait plus la peine d'être envoyée.
  static const minDimension = 64;

  const InMemoryAttachmentCompressor(this._store, {Uuid uuid = const Uuid()})
    : _uuid = uuid;

  @override
  Future<AttachmentDraft?> compress(
    AttachmentDraft draft, {
    required int targetBytes,
  }) async {
    var width = draft.width ?? 320;
    var height = draft.height ?? 240;

    while (width >= minDimension && height >= minDimension) {
      final bytes = SampleImage.solid(
        width: width,
        height: height,
        argb: 0xFF8A5100,
      );
      if (bytes.length <= targetBytes) {
        final compressed = draft.compressedTo(
          uri: 'memory://compressed-${_uuid.v4()}',
          byteSize: bytes.length,
          width: width,
          height: height,
        );
        _store.registerDraft(compressed, bytes);
        return compressed;
      }
      width = (width * 0.7).round();
      height = (height * 0.7).round();
    }
    // Même au plancher, la cible reste hors d'atteinte.
    return null;
  }
}
