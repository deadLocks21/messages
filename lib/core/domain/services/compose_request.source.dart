import 'package:messages/core/domain/model/compose_request.dart';

/// Port des demandes de rédaction venues de l'extérieur.
///
/// Deux temps, comme tout mécanisme de lien entrant : celle qui a *lancé* l'app
/// ([initial], consommée une seule fois) et celles qui arrivent alors qu'elle
/// tourne déjà ([requests]).
abstract interface class ComposeRequestSource {
  /// Demande ayant lancé l'application, s'il y en a une. L'appel la consomme :
  /// un second appel rend `null`, pour qu'un rebuild ne rejoue pas la
  /// navigation.
  Future<ComposeRequest?> initial();

  /// Demandes reçues pendant que l'app est ouverte.
  Stream<ComposeRequest> get requests;
}
