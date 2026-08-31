import 'package:messages/core/domain/model/gif.dart';

/// Port du **catalogue de GIF** — Klipy ici, Tenor dans l'app d'origine.
///
/// Trois lectures, et rien d'autre : ce port ne rend que des **adresses**.
/// Une grille qui garderait ses GIF en mémoire pèserait plus lourd que le fil
/// qu'elle recouvre, et le fichier qui partira n'a de toute façon pas de
/// raison d'exister avant qu'un GIF soit choisi — c'est
/// [MediaDownloader] qui le fera naître, une fois, pour celui-là.
abstract interface class GifCatalog {
  /// Ce que le catalogue met en avant, faute de recherche. C'est ce qui
  /// remplit la grille à l'ouverture du panneau.
  Future<GifPage> featured({String? cursor});

  /// La même grille, pour un terme. Une recherche vide rend [GifPage.empty] —
  /// pas les résultats mis en avant : c'est à l'appelant de choisir.
  Future<GifPage> search(String query, {String? cursor});

  /// Les puces de recherche toute faite, sous le champ.
  Future<List<GifCategory>> categories();
}
