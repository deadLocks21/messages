/// Port vers la fiche contact du système — celle de l'app Contacts, pas la
/// nôtre.
///
/// L'app ne montre jamais de fiche : elle **passe la main**. C'est ce que fait
/// Google Messages, dont les boutons « Infos contact » et « Ajouter un
/// contact » ouvrent l'app Contacts d'Android plutôt que d'en réimplémenter
/// l'écran. Un client SMS n'a rien à dire du carnet d'adresses qu'il ne sache
/// déjà : un nom, des numéros, une vignette — tout le reste (adresses,
/// anniversaires, comptes liés, fusion de doublons) appartient à l'app qui les
/// détient.
abstract interface class ContactCardService {
  /// Ouvre la fiche existante d'un contact du carnet.
  ///
  /// Rend `false` quand rien ne s'est ouvert (aucune app de contacts, fiche
  /// disparue depuis la lecture du carnet) : l'appelant peut alors le dire,
  /// plutôt que de laisser un appui sans effet.
  Future<bool> open(String contactId);

  /// Ouvre la création d'une fiche, pré-remplie de [address].
  ///
  /// Le contact n'est pas créé ici : l'app Contacts s'ouvre sur un formulaire
  /// que l'utilisateur valide ou non. On ne saura pas ce qu'il en a fait —
  /// c'est le retour au premier plan qui relira le carnet.
  Future<bool> create(String address);
}
