import 'dart:math';

/// L'encodage d'un SMS. Il vaut pour le **message entier**, jamais caractère
/// par caractère : un seul « ê » suffit à faire basculer tout le texte, et à
/// faire tomber la capacité d'un segment de 160 à 70 caractères.
enum SmsEncoding {
  /// Alphabet GSM 7 bits par défaut (3GPP TS 23.038 §6.2.1).
  gsm7bit,

  /// Tout le reste : chaque caractère y coûte une unité UTF-16.
  ucs2,
}

/// Ce qu'un texte coûtera une fois parti : combien de SMS, et quelle place
/// reste dans le dernier.
///
/// **C'est le calcul de `SmsSegments.kt`**, qui découpe pour de vrai au moment
/// de l'envoi (cf. « Envoyer un SMS long » dans ARCHITECTURE.md) : mêmes
/// tables, mêmes limites, même refus de couper une paire en deux. Le compteur
/// du champ de rédaction annonce ce que le natif fera — dès que les deux
/// règles divergent, il ment.
///
/// Pourquoi ne pas demander le découpage au natif plutôt que de l'écrire deux
/// fois ? Parce que le compteur se recalcule à **chaque frappe** : ce serait un
/// aller-retour par caractère sur le canal de plateforme pour un calcul qui
/// tient en trente lignes — et le champ n'afficherait plus rien sur la démo
/// macOS, où il n'y a pas de natif au bout du canal.
class SmsSegments {
  const SmsSegments._({
    required this.count,
    required this.remaining,
    required this.encoding,
  });

  /// Ce que coûte [body], selon la règle du 3GPP TS 23.038 : 7 bits tant que
  /// tout le texte tient dans l'alphabet GSM, UCS-2 sinon.
  factory SmsSegments.of(String body) {
    final septets = _septetCost(body);
    return septets == null ? _units(body) : _septets(body, septets);
  }

  /// Un SMS 7 bits qui part seul : 140 octets, soit 160 septets.
  static const septetsSingle = 160;

  /// Concaténé : l'en-tête UDH mange 6 octets, il reste 153 septets.
  static const septetsConcatenated = 153;

  /// Un SMS UCS-2 qui part seul : 140 octets, soit 70 caractères.
  static const unitsSingle = 70;

  /// Concaténé : 134 octets, soit 67 caractères.
  static const unitsConcatenated = 67;

  /// Nombre de SMS que produira le corps. Vaut 1 pour un texte vide : c'est ce
  /// que le découpage natif rend, lui aussi.
  final int count;

  /// Ce qui tient encore dans le **dernier** segment, dans l'unité de
  /// [encoding] : des septets en 7 bits — où le « € » en coûte deux — et des
  /// unités UTF-16 en UCS-2, où un emoji en occupe deux.
  ///
  /// C'est la place réellement libre, pas une soustraction sur le nombre de
  /// caractères : une paire d'échappement repoussée au segment suivant laisse
  /// un septet perdu derrière elle, et ce septet-là n'est plus disponible.
  final int remaining;

  final SmsEncoding encoding;

  /// Alphabet GSM 7 bits par défaut, échappement (0x1B) exclu : il n'encode
  /// aucun caractère saisissable, il n'annonce que la table d'extension.
  static final _basic =
      ('@£\$¥èéùìòÇ\nØø\rÅå'
              'Δ_ΦΓΛΩΠΨΣΘΞÆæßÉ'
              ' !"#¤%&\'()*+,-./'
              '0123456789:;<=>?'
              '¡ABCDEFGHIJKLMNO'
              'PQRSTUVWXYZÄÖÑÜ§'
              '¿abcdefghijklmno'
              'pqrstuvwxyzäöñüà')
          .codeUnits
          .toSet();

  /// Table d'extension : ces caractères s'écrivent en deux septets
  /// (échappement + code), et la paire ne se coupe pas entre deux segments.
  static final _extended = '^{}\\[~]|€'.codeUnits.toSet();

  /// Coût du corps en septets, ou `null` dès qu'un caractère sort de
  /// l'alphabet GSM — auquel cas le message entier part en UCS-2.
  static int? _septetCost(String body) {
    var total = 0;
    for (final unit in body.codeUnits) {
      final septets = _septetsOf(unit);
      if (septets == null) return null;
      total += septets;
    }
    return total;
  }

  static int? _septetsOf(int unit) {
    if (_basic.contains(unit)) return 1;
    if (_extended.contains(unit)) return 2;
    return null;
  }

  static SmsSegments _septets(String body, int total) {
    if (total <= septetsSingle) {
      return SmsSegments._(
        count: 1,
        remaining: septetsSingle - total,
        encoding: SmsEncoding.gsm7bit,
      );
    }

    var count = 1;
    var cost = 0;
    for (final unit in body.codeUnits) {
      // `_septetCost` a déjà tout reconnu : le coût ne peut plus manquer.
      final septets = _septetsOf(unit)!;
      // Le segment se ferme *avant* le caractère qui ne tient plus : une paire
      // d'échappement part entière dans le suivant plutôt que de se retrouver
      // à cheval sur les deux.
      if (cost + septets > septetsConcatenated) {
        count++;
        cost = 0;
      }
      cost += septets;
    }
    return SmsSegments._(
      count: count,
      remaining: septetsConcatenated - cost,
      encoding: SmsEncoding.gsm7bit,
    );
  }

  static SmsSegments _units(String body) {
    if (body.length <= unitsSingle) {
      return SmsSegments._(
        count: 1,
        remaining: unitsSingle - body.length,
        encoding: SmsEncoding.ucs2,
      );
    }

    var count = 0;
    var start = 0;
    var last = 0;
    while (start < body.length) {
      var end = min(start + unitsConcatenated, body.length);
      // Un emoji sort du plan de base : il occupe deux unités UTF-16. Les
      // séparer donnerait deux moitiés de caractère, que le destinataire
      // verrait comme deux losanges — le segment rend donc une unité.
      if (end < body.length && _isHighSurrogate(body.codeUnitAt(end - 1))) {
        end--;
      }
      last = end - start;
      start = end;
      count++;
    }
    return SmsSegments._(
      count: count,
      remaining: unitsConcatenated - last,
      encoding: SmsEncoding.ucs2,
    );
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}
