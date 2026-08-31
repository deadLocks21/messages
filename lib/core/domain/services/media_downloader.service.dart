import 'package:messages/core/domain/model/attachment.dart';

/// Port du **rapatriement** d'un média distant.
///
/// Le pendant exact d'[AttachmentPicker] pour une pièce jointe qui n'est pas
/// sur l'appareil : là où le sélecteur ouvre un écran du système, celui-ci
/// ouvre une adresse — et les deux rendent la même chose, un [AttachmentDraft]
/// prêt à partir.
///
/// Les octets ne remontent pas jusqu'ici : ce que rend [download] est une URI,
/// comme celle d'une photo prise ou d'un vocal enregistré. Le fichier vit dans
/// le cache de l'app, d'où l'envoi du MMS le relira.
abstract interface class MediaDownloader {
  /// Rapatrie [url] et en fait un brouillon de pièce jointe.
  ///
  /// [fileName] est le nom que portera la pièce jointe chez le destinataire :
  /// un fichier anonyme ne dit rien de ce qu'il contient. Lève quand rien n'a
  /// pu être rapatrié — une adresse périmée, un réseau absent : l'appelant
  /// doit pouvoir le dire, un plateau silencieusement vide passerait pour une
  /// panne.
  Future<AttachmentDraft> download(
    String url, {
    required String mimeType,
    required String fileName,
  });
}
