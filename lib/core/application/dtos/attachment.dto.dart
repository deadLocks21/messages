import 'package:messages/core/domain/model/attachment.dart';

/// Une pièce jointe prête à l'affichage.
///
/// Les octets n'y sont pas : l'UI les demande vignette par vignette (cf.
/// `attachmentBytesProvider`). Ce DTO ne porte que de quoi dessiner le
/// contenant — sa forme, son nom, son poids.
class AttachmentDto {
  final String id;
  final String mimeType;
  final AttachmentKind kind;

  /// Nom affiché sous l'icône d'un fichier. Toujours renseigné : à défaut de
  /// nom annoncé, un libellé de repli tiré du type.
  final String fileName;
  final int byteSize;
  final int? width;
  final int? height;

  /// Durée d'un son, quand le stock a su la mesurer. Le lecteur d'une bulle
  /// l'annonce avant toute lecture.
  final Duration? duration;

  const AttachmentDto({
    required this.id,
    required this.mimeType,
    required this.kind,
    required this.fileName,
    required this.byteSize,
    this.width,
    this.height,
    this.duration,
  });

  factory AttachmentDto.fromDomain(Attachment attachment) => AttachmentDto(
    id: attachment.id,
    mimeType: attachment.mimeType,
    kind: attachment.kind,
    fileName: attachment.fileName ?? defaultFileNameFor(attachment.kind),
    byteSize: attachment.byteSize,
    width: attachment.width,
    height: attachment.height,
    duration: attachment.duration,
  );

  /// Rapport largeur/hauteur, quand le stock l'a mesuré. Sert à réserver la
  /// bonne place avant que l'image soit décodée, plutôt que de faire sauter le
  /// fil.
  double? get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  /// « 240 Ko », « 1,2 Mo » — le poids tel que l'affiche l'app d'origine sous
  /// un fichier.
  String get sizeLabel => formatBytes(byteSize);

  /// « 00:04 » — la longueur d'un vocal, ou des tirets tant qu'elle est
  /// inconnue : une partie de MMS peut n'en annoncer aucune, et un lecteur qui
  /// afficherait « 00:00 » mentirait.
  String get durationLabel =>
      duration == null ? '--:--' : formatDuration(duration!);

  /// Ce qui remplace le texte dans la liste des conversations et les
  /// notifications : « Photo », « Vidéo »…
  String get previewLabel => previewLabelFor(kind);

  static String previewLabelFor(AttachmentKind kind) => switch (kind) {
    AttachmentKind.image => 'Photo',
    AttachmentKind.video => 'Vidéo',
    AttachmentKind.audio => 'Message audio',
    AttachmentKind.vcard => 'Contact',
    AttachmentKind.file => 'Pièce jointe',
  };

  static String defaultFileNameFor(AttachmentKind kind) => switch (kind) {
    AttachmentKind.image => 'Image',
    AttachmentKind.video => 'Vidéo',
    AttachmentKind.audio => 'Audio',
    AttachmentKind.vcard => 'Contact.vcf',
    AttachmentKind.file => 'Fichier',
  };

  /// « 00:04 », « 12:07 » — un vocal ne dépasse pas l'heure, deux champs
  /// suffisent.
  static String formatDuration(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final minutes = total.inMinutes;
    final seconds = total.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Poids lisible, en unités françaises (Ko/Mo, virgule décimale).
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
    final mo = bytes / (1024 * 1024);
    return '${mo.toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
}

/// Une pièce jointe en cours de rédaction, posée sur le plateau au-dessus du
/// champ de saisie.
class AttachmentDraftDto {
  final String id;
  final String mimeType;
  final AttachmentKind kind;
  final String fileName;
  final int byteSize;
  final int? width;
  final int? height;

  const AttachmentDraftDto({
    required this.id,
    required this.mimeType,
    required this.kind,
    required this.fileName,
    required this.byteSize,
    this.width,
    this.height,
  });

  factory AttachmentDraftDto.fromDomain(AttachmentDraft draft) =>
      AttachmentDraftDto(
        id: draft.id,
        mimeType: draft.mimeType,
        kind: draft.kind,
        fileName: draft.fileName,
        byteSize: draft.byteSize,
        width: draft.width,
        height: draft.height,
      );

  String get sizeLabel => AttachmentDto.formatBytes(byteSize);
}
