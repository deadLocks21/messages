import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/services/contact.repository.dart';

/// Index adresse → contact, construit une fois puis interrogé en O(1).
///
/// C'est le pendant applicatif de ce que fait Android en joignant
/// `content://sms` à `ContactsContract` : le stock SMS ne connaît que des
/// numéros, l'affichage veut des noms.
class ContactDirectory {
  final Map<String, Contact> _byAddressKey;
  final List<Contact> all;

  ContactDirectory._(this._byAddressKey, this.all);

  static final empty = ContactDirectory._(const {}, const []);

  factory ContactDirectory.from(List<Contact> contacts) {
    final index = <String, Contact>{};
    for (final contact in contacts) {
      for (final address in contact.addresses) {
        // Premier arrivé, premier servi : deux fiches partageant un numéro sont
        // rares, et l'ordre du carnet est déjà l'ordre d'affichage.
        index.putIfAbsent(address.key, () => contact);
      }
    }
    return ContactDirectory._(index, List.unmodifiable(contacts));
  }

  Contact? lookup(Address address) => _byAddressKey[address.key];

  /// Nom affichable d'une adresse : le contact s'il existe, sinon le numéro
  /// formaté (ou l'expéditeur alphanumérique tel quel).
  String nameFor(Address address) => lookup(address)?.displayName ?? address.display;

  /// Titre d'un fil : « Alice », « Alice, Bob » ou « 06 12 34 56 78 ».
  String titleFor(List<Address> addresses) =>
      addresses.map(nameFor).join(', ');

  /// Graine de couleur d'avatar : le nom du contact quand il existe, pour que
  /// la pastille suive le contact même si le fil utilise un autre de ses
  /// numéros.
  String colorSeedFor(List<Address> addresses) {
    if (addresses.isEmpty) return '';
    final first = addresses.first;
    return lookup(first)?.displayName ?? first.key;
  }
}

/// Charge le carnet d'adresses et en fait un [ContactDirectory].
class ContactDirectoryService {
  final ContactRepository _contacts;

  const ContactDirectoryService(this._contacts);

  /// Une permission refusée ou un carnet indisponible ne doit pas casser la
  /// liste des conversations : on retombe sur un annuaire vide, et l'UI affiche
  /// les numéros bruts.
  Future<ContactDirectory> load() async {
    try {
      return ContactDirectory.from(await _contacts.listAll());
    } catch (_) {
      return ContactDirectory.empty;
    }
  }
}
