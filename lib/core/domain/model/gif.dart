/// Une **déclinaison** d'un GIF : le même dessin, servi à une autre taille.
///
/// Un catalogue de GIF ne rend pas un fichier mais une famille — du plein
/// format au timbre-poste — et c'est ce qui change tout pour un MMS : la
/// taille se **choisit** avant l'envoi, au lieu de se rattraper après coup
/// comme pour une photo prise à l'appareil.
class GifRendition {
  /// Où le fichier se télécharge. Opaque : seule l'infrastructure la suit.
  final String url;
  final int width;
  final int height;

  /// Poids annoncé par le catalogue. C'est **lui** qui décide de la
  /// déclinaison retenue, et il est connu sans rien télécharger.
  final int byteSize;

  const GifRendition({
    required this.url,
    required this.width,
    required this.height,
    required this.byteSize,
  }) : assert(url != '', 'url cannot be empty'),
       assert(width > 0, 'width must be positive'),
       assert(height > 0, 'height must be positive'),
       assert(byteSize >= 0, 'byteSize cannot be negative');

  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GifRendition &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Un GIF du catalogue, avec ses déclinaisons.
///
/// L'entité ne porte **aucun octet** : une grille de GIF animés en mémoire
/// pèserait plus lourd qu'un fil de vacances. Elle porte des adresses, et
/// c'est l'affichage qui va chercher l'aperçu, une vignette à la fois.
class Gif {
  /// Identifiant du catalogue. Sert de clé de liste et d'identité.
  final String id;

  /// Ce que le GIF montre, tel que le catalogue le décrit (« Happy Dog Day »).
  /// C'est le seul texte que porte une vignette, et donc ce qu'un lecteur
  /// d'écran annonce.
  final String description;

  /// La déclinaison **affichée dans la grille** : légère par construction,
  /// parce qu'une grille en fait défiler des dizaines.
  ///
  /// Ce n'est pas forcément un GIF — le catalogue sert le même dessin en WebP
  /// pour trois fois moins lourd, et rien ne part d'ici. Ce qui s'envoie sort
  /// de [renditions], et seulement de là.
  final GifRendition preview;

  /// Les déclinaisons **joignables**, de la plus lourde à la plus légère.
  ///
  /// Toutes sont des GIF ([sentMimeType]) : le catalogue en sert aussi en MP4
  /// et en WebM, mais un MMS qui les porterait ne serait plus un GIF chez le
  /// destinataire — ce serait une vidéo.
  final List<GifRendition> renditions;

  /// Une image floue, minuscule, à afficher **pendant** que le GIF arrive.
  ///
  /// Le catalogue la fournit déjà encodée (`data:image/jpeg;base64,…`), pour
  /// quelques centaines d'octets : c'est ce qui remplit la vignette tout de
  /// suite, aux bonnes couleurs, au lieu d'un rectangle uni. Null quand le
  /// catalogue n'en publie pas.
  final String? blurPreview;

  /// Le type MIME sous lequel un GIF part en MMS.
  ///
  /// Porté par l'entité et non par la déclinaison : c'est une propriété de ce
  /// qui s'envoie, pas de chaque ligne du catalogue — dont l'aperçu, lui, peut
  /// être tout autre chose.
  static const sentMimeType = 'image/gif';

  Gif({
    required this.id,
    required this.description,
    required this.preview,
    required List<GifRendition> renditions,
    this.blurPreview,
  }) : renditions = List.unmodifiable(
         [...renditions]..sort((a, b) => b.byteSize.compareTo(a.byteSize)),
       ),
       assert(id != '', 'id cannot be empty'),
       assert(renditions.isNotEmpty, 'a gif needs at least one rendition');

  /// La plus belle déclinaison qui tienne dans [budgetBytes].
  ///
  /// C'est **ici** que se joue la taille du GIF envoyé, et elle se joue à la
  /// sélection : un MMS refusé par le MMSC arriverait trop tard pour être
  /// réparable, et un GIF ne se rattrape pas — le ré-encoder en JPEG le
  /// figerait, ce qui d'un GIF ne laisse rien.
  ///
  /// Rend `null` quand même la plus petite déborde : c'est un refus franc, du
  /// même ordre que celui d'une vidéo trop lourde. Cela arrive vraiment —
  /// certains catalogues encodent leurs GIF si largement que même leur plus
  /// petite déclinaison dépasse le budget de repli d'un MMS.
  GifRendition? bestWithin(int budgetBytes) {
    for (final rendition in renditions) {
      if (rendition.byteSize <= budgetBytes) return rendition;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Gif && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Une des puces sous le champ de recherche (`#lazy`, `#stressed`…).
///
/// Ce n'est pas un filtre mais une **recherche toute faite** : la toucher
/// revient à taper son terme. D'où les deux champs — ce qui s'affiche n'est
/// pas toujours ce qui se cherche.
class GifCategory {
  final String label;
  final String query;

  const GifCategory({required this.label, required this.query})
    : assert(label != '', 'label cannot be empty'),
      assert(query != '', 'query cannot be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GifCategory &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          query == other.query;

  @override
  int get hashCode => Object.hash(label, query);
}

/// Une tranche de résultats, et de quoi demander la suivante.
///
/// La grille est sans fin : le catalogue rend une position (`cursor`) plutôt
/// qu'un numéro de page, et une position nulle veut dire qu'il n'y a plus
/// rien à défiler.
class GifPage {
  final List<Gif> gifs;
  final String? cursor;

  GifPage({required List<Gif> gifs, this.cursor})
    : gifs = List.unmodifiable(gifs);

  static final empty = GifPage(gifs: const []);

  bool get hasMore => cursor != null && cursor!.isNotEmpty;
}
