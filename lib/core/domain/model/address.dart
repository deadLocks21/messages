/// Value Object : adresse SMS. C'est ce que le stock Telephony appelle
/// `address` — le plus souvent un numéro (`+33612345678`, `0612345678`), mais
/// aussi un numéro court (`36002`) ou un expéditeur alphanumérique (`ORANGE`).
///
/// On ne rejette donc **rien** : un fil dont l'adresse est illisible reste un
/// fil affichable. La normalisation sert uniquement à comparer deux adresses
/// (`key`) et à les afficher joliment (`display`).
class Address {
  /// Adresse telle que fournie par le stock (ou saisie par l'utilisateur).
  final String raw;

  const Address._(this.raw);

  factory Address.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Adresse SMS vide');
    }
    return Address._(trimmed);
  }

  static Address? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return Address._(raw.trim());
  }

  /// Chiffres significatifs de l'adresse (préfixe international et séparateurs
  /// retirés). Vide pour un expéditeur alphanumérique.
  String get digits => raw.replaceAll(RegExp(r'[^0-9]'), '');

  /// Clé de comparaison, calquée sur `PhoneNumberUtils.compare` d'Android :
  /// deux numéros sont « le même » s'ils partagent leurs 9 derniers chiffres
  /// (`+33612345678` ≡ `0612345678`). Les adresses non numériques sont
  /// comparées en majuscules.
  String get key {
    final d = digits;
    if (d.isEmpty) return raw.toUpperCase();
    return d.length <= 9 ? d : d.substring(d.length - 9);
  }

  /// Chiffres significatifs d'une saisie, préfixe international ou zéro
  /// national retiré. Sert à comparer une saisie partielle à une adresse
  /// stockée : « 06 12 34 » doit retrouver « +33612345678 ».
  ///
  /// Volontairement centré sur le plan de numérotation français, comme le reste
  /// du formatage — un numéro étranger est comparé tel quel.
  static String significantDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    // 9 = longueur du numéro national significatif : au-delà, un `33` de tête
    // est l'indicatif pays, pas le début du numéro.
    if (digits.length > 9 && digits.startsWith('33')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  /// Numéro court d'un service (alerte bancaire, opérateur…).
  bool get isShortCode => digits.isNotEmpty && digits.length <= 6;

  /// Expéditeur nommé, qui ne peut pas recevoir de réponse.
  bool get isAlphanumeric => digits.isEmpty;

  /// Forme affichable : mobile français groupé par deux (`06 12 34 56 78`),
  /// adresse brute sinon.
  String get display {
    final d = digits;
    String? national;
    if (raw.startsWith('+33') && d.length == 11) {
      national = '0${d.substring(2)}';
    } else if (d.length == 10 && d.startsWith('0')) {
      national = d;
    }
    if (national == null) return raw;
    final groups = <String>[];
    for (var i = 0; i < national.length; i += 2) {
      groups.add(national.substring(i, i + 2));
    }
    return groups.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => raw;
}
