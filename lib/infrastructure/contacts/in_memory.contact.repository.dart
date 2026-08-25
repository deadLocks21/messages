import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/services/contact.repository.dart';

/// Carnet d'adresses en mémoire. Alimenté par le seed de démonstration hors
/// Android, et par les tests qui veulent des fils nommés.
class InMemoryContactRepository implements ContactRepository {
  final List<Contact> contacts;

  InMemoryContactRepository([List<Contact> contacts = const []])
    : contacts = [...contacts];

  @override
  Future<List<Contact>> listAll() async => List.unmodifiable(contacts);
}
