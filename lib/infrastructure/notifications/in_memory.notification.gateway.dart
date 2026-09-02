import 'package:messages/core/domain/services/notification.gateway.dart';

/// Doublure : retient le dernier état publié, ce qui suffit aux tests pour
/// vérifier qu'une mise en sourdine est bien redescendue jusqu'à la plateforme.
class InMemoryNotificationGateway implements NotificationGateway {
  /// Fil → échéance de la sourdine ; `null` en valeur = sans fin.
  Map<String, DateTime?> mutedThreads = {};
  Map<String, String> directory = {};

  @override
  Future<void> setMutedThreads(Map<String, DateTime?> mutedUntil) async =>
      mutedThreads = {...mutedUntil};

  @override
  Future<void> setDirectory(Map<String, String> namesByAddressKey) async =>
      directory = {...namesByAddressKey};
}
