import 'dart:typed_data';

import 'package:messages/core/domain/model/address.dart';

/// Fiche du carnet d'adresses, réduite à ce dont Messages a besoin : un nom,
/// des numéros, et une vignette pour l'avatar.
class Contact {
  final String id;
  final String displayName;
  final List<Address> addresses;

  /// Vignette (JPEG/PNG) fournie par le carnet d'adresses. Null ⇒ l'UI retombe
  /// sur la pastille colorée à initiale.
  final Uint8List? photo;

  Contact({
    required this.id,
    required this.displayName,
    required this.addresses,
    this.photo,
  }) : assert(id != '', 'id cannot be empty');

  /// Initiale affichée dans l'avatar par défaut. Vide si le nom ne commence pas
  /// par une lettre (l'UI affiche alors une icône générique).
  String get initial {
    final letter = displayName.trim().split('').firstWhere(
      (c) => RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(c),
      orElse: () => '',
    );
    return letter.toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
