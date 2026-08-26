/// Nature d'une pièce jointe, déduite de son type MIME.
///
/// Le stock MMS ne connaît que des types MIME ; l'UI, elle, a besoin de savoir
/// s'il faut afficher une vignette, un lecteur ou une simple ligne de fichier.
enum AttachmentKind {
  image,
  video,
  audio,
  vcard,
  file;

  static AttachmentKind fromMimeType(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime.startsWith('image/')) return AttachmentKind.image;
    if (mime.startsWith('video/')) return AttachmentKind.video;
    if (mime.startsWith('audio/')) return AttachmentKind.audio;
    if (mime == 'text/x-vcard' || mime == 'text/vcard') {
      return AttachmentKind.vcard;
    }
    return AttachmentKind.file;
  }

  bool get isVisual =>
      this == AttachmentKind.image || this == AttachmentKind.video;
}

/// Bornes d'un MMS.
///
/// Le réseau plafonne la taille du PDU ; les opérateurs français acceptent
/// couramment 300 Ko, rarement plus de 600 Ko. On s'arrête à 600 Ko de contenu
/// utile — au-delà, l'envoi partirait pour échouer silencieusement côté MMSC,
/// ce qui est le pire des retours pour l'utilisateur.
abstract final class AttachmentLimits {
  static const maxTotalBytes = 600 * 1024;
  static const maxCount = 10;
}

/// Une pièce jointe **déjà dans le stock** : une partie de MMS
/// (`content://mms/part`).
///
/// Les octets ne sont pas portés ici — un fil de vacances les ferait tous
/// tenir en mémoire. L'UI les demande à la demande via [AttachmentRepository].
class Attachment {
  /// `_id` de la partie dans `content://mms/part`.
  final String id;
  final String mimeType;

  /// Nom de fichier annoncé par l'émetteur, quand il y en a un.
  final String? fileName;
  final int byteSize;

  /// Dimensions en pixels, connues seulement pour les images déjà mesurées.
  final int? width;
  final int? height;

  Attachment({
    required this.id,
    required this.mimeType,
    this.fileName,
    this.byteSize = 0,
    this.width,
    this.height,
  }) : assert(id != '', 'id cannot be empty'),
       assert(mimeType != '', 'mimeType cannot be empty'),
       assert(byteSize >= 0, 'byteSize cannot be negative');

  AttachmentKind get kind => AttachmentKind.fromMimeType(mimeType);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attachment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Une pièce jointe **choisie mais pas encore envoyée**.
///
/// Elle vit hors du stock, dans un fichier local ou derrière une URI de
/// contenu : le domaine ne sait pas la lire, il ne fait que la transporter
/// jusqu'au repository qui l'écrira dans le MMS.
class AttachmentDraft {
  /// Identifiant local, stable le temps de la rédaction — c'est lui qui permet
  /// de retirer une vignette précise du plateau.
  final String id;

  /// URI opaque (`content://…` ou `file://…`) comprise par la seule
  /// infrastructure.
  final String uri;
  final String mimeType;
  final String fileName;
  final int byteSize;
  final int? width;
  final int? height;

  AttachmentDraft({
    required this.id,
    required this.uri,
    required this.mimeType,
    required this.fileName,
    this.byteSize = 0,
    this.width,
    this.height,
  }) : assert(id != '', 'id cannot be empty'),
       assert(uri != '', 'uri cannot be empty'),
       assert(mimeType != '', 'mimeType cannot be empty'),
       assert(byteSize >= 0, 'byteSize cannot be negative');

  AttachmentKind get kind => AttachmentKind.fromMimeType(mimeType);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentDraft &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
