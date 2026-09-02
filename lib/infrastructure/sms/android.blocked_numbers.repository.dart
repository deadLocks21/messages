import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/services/blocked_numbers.repository.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';

/// Les numéros bloqués du système, par le pont natif.
class AndroidBlockedNumbersRepository implements BlockedNumbersRepository {
  final AndroidSmsChannel _channel;

  const AndroidBlockedNumbersRepository(this._channel);

  @override
  Future<List<Address>> listAll() => _channel.listBlockedNumbers();

  @override
  Future<void> block(Address address) => _channel.blockNumber(address);

  @override
  Future<void> unblock(Address address) => _channel.unblockNumber(address);
}
