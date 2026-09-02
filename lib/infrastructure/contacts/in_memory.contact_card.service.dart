import 'package:messages/core/domain/services/contact_card.service.dart';

/// Fiche contact simulée : hors Android il n'y a pas d'app Contacts à ouvrir.
///
/// Elle ne rend pas `false` pour autant — un `false` veut dire « l'appareil
/// n'a rien pour ça », et l'écran l'annonce ; la démo de bureau, elle, doit
/// pouvoir montrer que le bouton part quelque part. Les tests lisent
/// [opened] et [created] pour vérifier où.
class InMemoryContactCardService implements ContactCardService {
  /// Identifiants de contact dont la fiche a été ouverte, dans l'ordre.
  final List<String> opened = [];

  /// Numéros pour lesquels une création de fiche a été demandée.
  final List<String> created = [];

  /// Simule un appareil sans app de contacts.
  bool available;

  InMemoryContactCardService({this.available = true});

  @override
  Future<bool> open(String contactId) async {
    if (!available) return false;
    opened.add(contactId);
    return true;
  }

  @override
  Future<bool> create(String address) async {
    if (!available) return false;
    created.add(address);
    return true;
  }
}
