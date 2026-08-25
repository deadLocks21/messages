import 'package:messages/core/application/dtos/contact.dto.dart';
import 'package:messages/core/application/services/avatar_palette.service.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/contact.dart';

/// Alimente le sélecteur de destinataires : le carnet d'adresses, filtré par ce
/// que l'utilisateur tape (nom ou numéro), plus l'entrée « envoyer à ce numéro »
/// quand la saisie ressemble à un numéro absent du carnet.
class ContactPickerService {
  final ContactDirectoryService _directory;

  const ContactPickerService(this._directory);

  Future<List<ContactDto>> suggestions({String query = ''}) async {
    final directory = await _directory.load();
    final needle = query.trim().toLowerCase();
    final digits = Address.significantDigits(query);

    final matches = directory.all.where((c) => _matches(c, needle, digits)).toList();
    final results = matches
        .map(
          (c) => ContactDto.fromDomain(
            c,
            colorSlot: AvatarPaletteService.slotFor(c.displayName),
          ),
        )
        .toList();

    // Numéro tapé à la main : Google Messages propose de l'utiliser tel quel,
    // en tête de liste. Inutile en revanche de le répéter quand un contact
    // proposé porte déjà ces chiffres — la saisie est alors juste un début de
    // numéro connu.
    final typed = Address.tryParse(query);
    final alreadyProposed = results.any(
      (c) => c.addresses.any((a) => Address.significantDigits(a).contains(digits)),
    );
    if (typed != null &&
        digits.length >= 4 &&
        !alreadyProposed &&
        directory.lookup(typed) == null) {
      results.insert(
        0,
        ContactDto.unknown(
          typed,
          colorSlot: AvatarPaletteService.slotFor(typed.key),
        ),
      );
    }
    return results;
  }

  /// Fiche d'une adresse quelconque : le contact s'il existe, une fiche
  /// minimale sinon.
  Future<ContactDto> forAddress(String raw) async {
    final address = Address.parse(raw);
    final directory = await _directory.load();
    final contact = directory.lookup(address);
    if (contact == null) {
      return ContactDto.unknown(
        address,
        colorSlot: AvatarPaletteService.slotFor(address.key),
      );
    }
    return ContactDto.fromDomain(
      contact,
      colorSlot: AvatarPaletteService.slotFor(contact.displayName),
    );
  }

  bool _matches(Contact contact, String needle, String digits) {
    if (needle.isEmpty) return true;
    if (contact.displayName.toLowerCase().contains(needle)) return true;
    if (digits.length < 2) return false;
    return contact.addresses.any(
      (a) => Address.significantDigits(a.raw).contains(digits),
    );
  }
}
