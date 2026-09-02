import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/services/blocked_numbers.repository.dart';

/// Numéros bloqués en mémoire, hors Android et dans les tests.
///
/// Indexés par `Address.key` et non par leur forme brute : bloquer
/// `+33612345678` doit bloquer `0612345678`, comme le fait la comparaison du
/// système.
class InMemoryBlockedNumbersRepository implements BlockedNumbersRepository {
  final Map<String, Address> _byKey = {};

  @override
  Future<List<Address>> listAll() async => List.unmodifiable(_byKey.values);

  @override
  Future<void> block(Address address) async => _byKey[address.key] = address;

  @override
  Future<void> unblock(Address address) async => _byKey.remove(address.key);
}
