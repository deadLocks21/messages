import 'package:messages/core/domain/model/sms_event.dart';

/// Port d'écoute du stock SMS : réception, accusés d'envoi/remise, et tout
/// autre changement.
///
/// Le flux est **broadcast** et démarre à la souscription. Une implémentation
/// ne doit jamais lever : une source indisponible se dégrade en flux vide (les
/// vues restent alors rafraîchies à la main / au retour au premier plan).
abstract interface class SmsEventSource {
  Stream<SmsEvent> get events;
}
