import 'package:messages/core/domain/model/compose_request.dart';
import 'package:messages/core/domain/services/compose_request.source.dart';

/// Aucune demande extérieure : hors Android, rien ne peut lancer l'app sur un
/// fil précis.
class InMemoryComposeRequestSource implements ComposeRequestSource {
  const InMemoryComposeRequestSource();

  @override
  Future<ComposeRequest?> initial() async => null;

  @override
  Stream<ComposeRequest> get requests => const Stream.empty();
}
