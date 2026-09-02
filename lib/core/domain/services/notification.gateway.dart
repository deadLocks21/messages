/// Port de configuration des notifications système.
///
/// Les notifications de SMS entrants sont publiées par la plateforme, depuis un
/// récepteur qui tourne souvent **sans moteur Dart attaché** : impossible de lui
/// demander à ce moment-là si le fil est en sourdine ou comment s'appelle
/// l'expéditeur. Ces deux informations lui sont donc poussées à l'avance, et il
/// les relit depuis son propre stockage au moment de notifier.
abstract interface class NotificationGateway {
  /// Fils dont les notifications sont coupées, et **jusqu'à quand**. Remplace
  /// l'ensemble précédent.
  ///
  /// Une valeur `null` veut dire « sans échéance » (la sourdine, ou la veille
  /// « Toujours ») ; une date veut dire une mise en veille, que le natif
  /// laissera expirer tout seul. C'est bien lui qui compare à l'heure
  /// courante : le récepteur tourne sans moteur Dart, et une veille qui arrive
  /// à terme pendant que l'app est fermée doit se terminer quand même.
  Future<void> setMutedThreads(Map<String, DateTime?> mutedUntil);

  /// Annuaire minimal `clé d'adresse → nom affichable`, pour que la
  /// notification porte « Camille » et non « +33612345678 ».
  Future<void> setDirectory(Map<String, String> namesByAddressKey);

  /// Ouvre les réglages de notification **du fil**, ceux du système.
  ///
  /// L'app ne les réimplémente pas : Android sait déjà régler une conversation
  /// (prioritaire, silencieuse, pastille, bulle), et c'est là que l'app
  /// d'origine envoie aussi. Rend `false` quand l'appareil n'a pas cet écran.
  Future<bool> openThreadSettings(String threadId);
}
