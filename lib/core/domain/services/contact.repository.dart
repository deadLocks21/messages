import 'package:messages/core/domain/model/contact.dart';

/// Port d'accès au carnet d'adresses. Sert à deux choses : nommer les fils
/// (adresse → contact) et alimenter le sélecteur de destinataires.
abstract interface class ContactRepository {
  /// Tous les contacts ayant au moins un numéro, vignettes comprises.
  /// Rend une liste vide si la permission Contacts n'est pas accordée — ce
  /// n'est pas une erreur, l'app affiche alors les numéros bruts.
  Future<List<Contact>> listAll();
}
