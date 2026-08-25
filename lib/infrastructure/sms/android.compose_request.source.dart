import 'package:messages/core/domain/model/compose_request.dart';
import 'package:messages/core/domain/services/compose_request.source.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// Demandes de rédaction transmises par l'`Activity` : intent `sms:`/`smsto:`
/// de lancement, ou reçu à chaud (`onNewIntent`) — c'est le chemin qu'emprunte
/// l'appui sur une notification de SMS reçu.
class AndroidComposeRequestSource implements ComposeRequestSource {
  final AndroidSmsChannel _channel;
  final Stream<ComposeRequest> _requests;

  AndroidComposeRequestSource(this._channel)
    : _requests = _channel.composeRequests().asBroadcastStream();

  @override
  Future<ComposeRequest?> initial() => _channel.consumeLaunchRequest();

  @override
  Stream<ComposeRequest> get requests => _requests;
}
