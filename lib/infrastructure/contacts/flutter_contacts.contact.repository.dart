import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/services/contact.repository.dart';

/// Carnet d'adresses réel (`ContactsContract`), via `flutter_contacts`.
///
/// Seuls les contacts ayant au moins un numéro sont rendus : les autres ne
/// peuvent ni nommer un fil ni recevoir de SMS.
class FlutterContactsContactRepository implements ContactRepository {
  const FlutterContactsContactRepository();

  @override
  Future<List<Contact>> listAll() async {
    if (!await fc.FlutterContacts.requestPermission(readonly: true)) {
      return const [];
    }

    final contacts = await fc.FlutterContacts.getContacts(
      withProperties: true,
      withThumbnail: true,
    );

    final mapped = contacts
        .map(_toDomain)
        .whereType<Contact>()
        .toList();
    mapped.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return mapped;
  }

  Contact? _toDomain(fc.Contact contact) {
    final addresses = contact.phones
        .map((p) => Address.tryParse(p.number))
        .whereType<Address>()
        .toList();
    if (addresses.isEmpty) return null;

    final name = contact.displayName.trim();
    return Contact(
      id: contact.id,
      // Une fiche sans nom (numéro enregistré à la volée) s'affiche par son
      // numéro plutôt que par une ligne vide.
      displayName: name.isEmpty ? addresses.first.display : name,
      addresses: addresses,
      photo: contact.thumbnail,
    );
  }
}
