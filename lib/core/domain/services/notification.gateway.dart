/// Port de configuration des notifications système.
///
/// Les notifications de SMS entrants sont publiées par la plateforme, depuis un
/// récepteur qui tourne souvent **sans moteur Dart attaché** : impossible de lui
/// demander à ce moment-là si le fil est en sourdine ou comment s'appelle
/// l'expéditeur. Ces deux informations lui sont donc poussées à l'avance, et il
/// les relit depuis son propre stockage au moment de notifier.
abstract interface class NotificationGateway {
  /// Fils dont les notifications sont coupées. Remplace l'ensemble précédent.
  Future<void> setMutedThreads(Set<String> threadIds);

  /// Annuaire minimal `clé d'adresse → nom affichable`, pour que la
  /// notification porte « Camille » et non « +33612345678 ».
  Future<void> setDirectory(Map<String, String> namesByAddressKey);
}
