import 'package:messages/core/domain/services/notification.gateway.dart';

/// Doublure : retient le dernier état publié, ce qui suffit aux tests pour
/// vérifier qu'une mise en sourdine est bien redescendue jusqu'à la plateforme.
class InMemoryNotificationGateway implements NotificationGateway {
  Set<String> mutedThreads = {};
  Map<String, String> directory = {};

  @override
  Future<void> setMutedThreads(Set<String> threadIds) async =>
      mutedThreads = {...threadIds};

  @override
  Future<void> setDirectory(Map<String, String> namesByAddressKey) async =>
      directory = {...namesByAddressKey};
}
