import 'package:messages/core/domain/model/sms_event.dart';
import 'package:messages/core/domain/services/sms_event.source.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// [SmsEventSource] branchée sur l'`EventChannel` natif : réceptions
/// `SMS_DELIVER`, accusés d'envoi et de remise, et changements du stock.
class AndroidSmsEventSource implements SmsEventSource {
  final Stream<SmsEvent> _events;

  AndroidSmsEventSource(AndroidSmsChannel channel)
    : _events = channel.events().asBroadcastStream();

  @override
  Stream<SmsEvent> get events => _events;
}
