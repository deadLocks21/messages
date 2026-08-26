import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/services/contact.repository.dart';

/// Carnet d'adresses en mémoire. Alimenté par le seed de démonstration hors
/// Android, et par les tests qui veulent des fils nommés.
class InMemoryContactRepository implements ContactRepository {
  final List<Contact> contacts;

  /// Nombre de lectures complètes du carnet.
  ///
  /// Sur un vrai appareil, chacune coûte le gros d'une seconde : c'est ce que
  /// [ContactDirectoryService] met en cache, et ce compteur est la seule façon
  /// pour un test de vérifier que le cache tient toujours.
  int readCount = 0;

  InMemoryContactRepository([List<Contact> contacts = const []])
    : contacts = [...contacts];

  @override
  Future<List<Contact>> listAll() async {
    readCount++;
    return List.unmodifiable(contacts);
  }
}
