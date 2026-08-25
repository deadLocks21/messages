import 'package:messages/core/domain/services/notification.gateway.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// Pousse les réglages de notification vers le natif, qui les persiste dans son
/// propre `SharedPreferences` — le récepteur `SMS_DELIVER` doit pouvoir les
/// relire sans moteur Dart.
class AndroidNotificationGateway implements NotificationGateway {
  final AndroidSmsChannel _channel;

  const AndroidNotificationGateway(this._channel);

  @override
  Future<void> setMutedThreads(Set<String> threadIds) =>
      _channel.setMutedThreads(threadIds);

  @override
  Future<void> setDirectory(Map<String, String> namesByAddressKey) =>
      _channel.setNotificationDirectory(namesByAddressKey);
}
