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

/// Bornes d'un MMS, telles que les fixe l'opérateur.
///
/// Ce plafond n'est pas une constante du protocole : chaque opérateur pose le
/// sien, et Android le publie dans sa configuration. Le deviner conduisait à
/// comprimer trop (photos dégradées pour rien) ou trop peu (message accepté
/// par personne). Il est donc **lu**, et [fallback] ne sert que lorsque la
/// configuration ne dit rien.
class MmsLimits {
  /// Taille maximale du message complet, enveloppe comprise.
  final int maxTotalBytes;

  const MmsLimits({required this.maxTotalBytes})
    : assert(maxTotalBytes > 0, 'maxTotalBytes must be positive');

  /// Valeur par défaut d'AOSP, retenue quand l'opérateur ne publie rien.
  /// Volontairement basse : mieux vaut un message qui passe qu'une photo nette
  /// que personne ne reçoit.
  static const fallback = MmsLimits(maxTotalBytes: 300 * 1024);

  /// Garde-fous contre une configuration aberrante — une valeur nulle,
  /// négative ou fantaisiste ne doit pas rendre l'envoi impossible ni faire
  /// exploser la mémoire.
  static const minPlausibleBytes = 64 * 1024;
  static const maxPlausibleBytes = 5 * 1024 * 1024;

  /// Nombre de pièces jointes par message. Ce plafond-là est le nôtre : rien
  /// dans le protocole ne l'impose, mais dix parties dans un MMS ne laissent
  /// déjà plus grand-chose à chacune.
  static const maxCount = 10;

  /// Marge laissée à l'enveloppe du MMS : en-têtes, SMIL de présentation,
  /// légende. Le contenu utile vise donc un peu moins que [maxTotalBytes],
  /// faute de quoi un message pile à la limite la dépasserait une fois encodé.
  static const envelopeBytes = 8 * 1024;

  /// Ce qui reste réellement pour les pièces jointes.
  int get contentBytes => maxTotalBytes - envelopeBytes;

  /// Ramène une valeur lue de la configuration dans le domaine du plausible.
  factory MmsLimits.fromCarrier(int? maxTotalBytes) {
    if (maxTotalBytes == null ||
        maxTotalBytes < minPlausibleBytes ||
        maxTotalBytes > maxPlausibleBytes) {
      return fallback;
    }
    return MmsLimits(maxTotalBytes: maxTotalBytes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MmsLimits &&
          runtimeType == other.runtimeType &&
          maxTotalBytes == other.maxTotalBytes;

  @override
  int get hashCode => maxTotalBytes.hashCode;
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

  /// Durée en millisecondes d'un son ou d'une vidéo, quand le stock a su la
  /// mesurer. Le lecteur d'une bulle l'affiche **avant** toute lecture — un
  /// vocal annonce sa longueur, c'est ce qui décide de l'écouter ou non.
  final int? durationMs;

  Attachment({
    required this.id,
    required this.mimeType,
    this.fileName,
    this.byteSize = 0,
    this.width,
    this.height,
    this.durationMs,
  }) : assert(id != '', 'id cannot be empty'),
       assert(mimeType != '', 'mimeType cannot be empty'),
       assert(byteSize >= 0, 'byteSize cannot be negative'),
       assert(
         durationMs == null || durationMs >= 0,
         'durationMs cannot be negative',
       );

  AttachmentKind get kind => AttachmentKind.fromMimeType(mimeType);

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

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
  /// infrastructure. C'est **ce qui sera envoyé**.
  final String uri;

  /// Ce que l'utilisateur a choisi, avant toute compression.
  ///
  /// Alléger une image déjà allégée dégraderait un peu plus à chaque fois : en
  /// ajoutant une troisième photo, les deux premières seraient recompressées
  /// à partir de leur version compressée. On repart donc toujours de
  /// l'original, qui reste désigné ici.
  final String sourceUri;
  final String mimeType;
  final String fileName;
  final int byteSize;
  final int? width;
  final int? height;

  /// Durée en millisecondes d'un vocal qu'on vient d'enregistrer.
  ///
  /// Connue **sans mesure** dans ce sens-là, contrairement à celle d'une pièce
  /// jointe reçue : c'est nous qui avons tenu le micro, et le compteur du
  /// panneau est la durée. Rien à redemander à un décodeur.
  final int? durationMs;

  AttachmentDraft({
    required this.id,
    required this.uri,
    String? sourceUri,
    required this.mimeType,
    required this.fileName,
    this.byteSize = 0,
    this.width,
    this.height,
    this.durationMs,
  }) : sourceUri = sourceUri ?? uri,
       assert(id != '', 'id cannot be empty'),
       assert(uri != '', 'uri cannot be empty'),
       assert(mimeType != '', 'mimeType cannot be empty'),
       assert(byteSize >= 0, 'byteSize cannot be negative'),
       assert(
         durationMs == null || durationMs >= 0,
         'durationMs cannot be negative',
       );

  AttachmentKind get kind => AttachmentKind.fromMimeType(mimeType);

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  /// Cette pièce jointe peut-elle être allégée ?
  ///
  /// Seules les images fixes. Une vidéo demanderait un ré-encodage complet, un
  /// PDF n'a rien de superflu à jeter : pour eux, trop lourd veut dire trop
  /// lourd.
  ///
  /// **Un GIF non plus**, alors que c'en est pourtant une : le compresseur
  /// ré-encode en JPEG, et un JPEG ne bouge pas. Alléger un GIF reviendrait à
  /// n'en garder qu'une image — ce qui, d'un GIF, ne laisse rien. Sa taille se
  /// choisit donc en amont, parmi les déclinaisons du catalogue
  /// ([Gif.bestWithin]), et pas ici.
  bool get isCompressible =>
      kind == AttachmentKind.image && mimeType.toLowerCase() != gifMimeType;

  /// Le type d'un GIF animé, seul type d'image que l'app ne comprime pas.
  static const gifMimeType = 'image/gif';

  /// La même pièce jointe, allégée : nouveau fichier, même identité.
  ///
  /// Le type peut changer — ré-encoder produit du JPEG quel que soit
  /// l'original — et le nom suit, sinon le MMS annoncerait un `.png` contenant
  /// du JPEG.
  AttachmentDraft compressedTo({
    required String uri,
    required int byteSize,
    String? mimeType,
    int? width,
    int? height,
  }) {
    final type = mimeType ?? this.mimeType;
    return AttachmentDraft(
      id: id,
      uri: uri,
      sourceUri: sourceUri,
      mimeType: type,
      fileName: type == this.mimeType
          ? fileName
          : _renamedFor(fileName, type),
      byteSize: byteSize,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs,
    );
  }

  /// Le même nom, avec l'extension du nouveau type.
  static String _renamedFor(String fileName, String mimeType) {
    final extension = switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => null,
    };
    if (extension == null) return fileName;
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    return '$stem.$extension';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentDraft &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
