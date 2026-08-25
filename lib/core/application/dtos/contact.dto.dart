import 'package:messages/core/application/dtos/avatar.dto.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/contact.dart';

/// Un contact tel que l'affiche le sélecteur de destinataires.
class ContactDto {
  final String id;
  final String displayName;

  /// Numéros du contact, en forme brute (celle qu'on renverra au stock).
  final List<String> addresses;

  /// Numéro affiché sous le nom (le premier du contact).
  final String primaryAddressLabel;

  final AvatarDto avatar;

  const ContactDto({
    required this.id,
    required this.displayName,
    required this.addresses,
    required this.primaryAddressLabel,
    required this.avatar,
  });

  factory ContactDto.fromDomain(Contact contact, {required int colorSlot}) {
    return ContactDto(
      id: contact.id,
      displayName: contact.displayName,
      addresses: contact.addresses.map((a) => a.raw).toList(),
      primaryAddressLabel: contact.addresses.isEmpty
          ? ''
          : contact.addresses.first.display,
      avatar: AvatarDto(
        initial: contact.initial,
        colorSlot: colorSlot,
        photo: contact.photo,
      ),
    );
  }

  /// Fiche synthétique pour un numéro saisi à la main, absent du carnet.
  factory ContactDto.unknown(Address address, {required int colorSlot}) {
    return ContactDto(
      id: 'address:${address.key}',
      displayName: address.display,
      addresses: [address.raw],
      primaryAddressLabel: address.display,
      avatar: AvatarDto(initial: '', colorSlot: colorSlot),
    );
  }
}
