import 'package:intl/intl.dart';

/// Formats de date de Google Messages. Regroupés ici pour que les écrans ne
/// réinventent pas chacun leur règle « aujourd'hui / hier / cette semaine ».
///
/// [now] est injectable pour que les tests n'aient pas à composer avec l'heure
/// réelle.
abstract final class MessagesDateFormat {
  static const _locale = 'fr_FR';

  /// Horodatage d'une ligne de la liste des conversations : l'heure le jour
  /// même, puis de plus en plus grossier en remontant le temps.
  static String conversationStamp(DateTime at, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (_isSameDay(at, reference)) {
      return DateFormat.Hm(_locale).format(at);
    }
    if (_isSameDay(at, reference.subtract(const Duration(days: 1)))) {
      return 'hier';
    }
    if (reference.difference(at) < const Duration(days: 7)) {
      return DateFormat.E(_locale).format(at);
    }
    if (at.year == reference.year) {
      return DateFormat.MMMd(_locale).format(at);
    }
    return DateFormat('dd/MM/yyyy', _locale).format(at);
  }

  /// Séparateur affiché entre deux salves de messages.
  static String separator(DateTime at, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final time = DateFormat.Hm(_locale).format(at);
    if (_isSameDay(at, reference)) return time;
    if (_isSameDay(at, reference.subtract(const Duration(days: 1)))) {
      return 'Hier, $time';
    }
    if (reference.difference(at) < const Duration(days: 7)) {
      return '${DateFormat.E(_locale).format(at)} $time';
    }
    if (at.year == reference.year) {
      return '${DateFormat.MMMEd(_locale).format(at)}, $time';
    }
    return '${DateFormat.yMMMd(_locale).format(at)}, $time';
  }

  /// Date complète, pour la fiche « Détails du message ».
  static String full(DateTime at) =>
      DateFormat('EEEE d MMMM y \'à\' HH:mm', _locale).format(at);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
