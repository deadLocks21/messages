/// Ce que l'app est en train de faire, tel qu'on veut le retrouver sur
/// *chaque* ligne de log.
///
/// Un enregistrement isolé ne dit presque rien : « `mms.compress_failed` » ne
/// devient exploitable qu'accompagné de l'écran où l'utilisateur se trouvait et
/// de l'état des autorisations à ce moment-là. Plutôt que d'obliger chaque site
/// d'appel à re-décrire son décor, ce contexte est tenu à jour par les rares
/// endroits qui le connaissent (le routeur, le contrôleur d'accès SMS) et lu au
/// vol par `LoggerApplicationService` à chaque émission.
///
/// Mutable et volontairement minuscule : c'est un jeu d'attributs, pas un
/// état applicatif. Rien ici ne doit être une source de vérité — la route
/// courante appartient à `GoRouter`, l'accès SMS à `SmsAccessController` ;
/// cette classe n'en garde qu'un décalque destiné aux logs.
class AppLogContext {
  /// Identifiant de ce lancement d'app. Ce qui permet de recoller les lignes
  /// d'une même session dans Signoz, faute d'identifiant d'appareil : l'app
  /// n'a pas de compte, donc pas d'`user.id` à donner.
  final String sessionId;

  /// Route affichée, telle que `GoRouter` la nomme (`/thread/:id` et non
  /// `/thread/42` — un identifiant de fil dans une clé de log en ferait une
  /// dimension à cardinalité infinie).
  String? route;

  /// L'app est-elle application SMS par défaut ? Sans le rôle, la moitié des
  /// échecs d'écriture s'expliquent d'eux-mêmes.
  bool? isDefaultSmsApp;

  AppLogContext({required this.sessionId});

  /// Attributs à fusionner dans l'enregistrement en cours d'émission. Les
  /// champs non renseignés sont omis plutôt qu'envoyés vides : une colonne
  /// absente se lit mieux qu'une colonne pleine de `null`.
  Map<String, Object?> snapshot() => {
    'session.id': sessionId,
    if (route != null) 'app.route': route,
    if (isDefaultSmsApp != null) 'sms.default_app': isDefaultSmsApp,
  };
}
