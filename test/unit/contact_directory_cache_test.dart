import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/services/contact.repository.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';

import '../builders/builders.dart';

/// Un carnet qui refuse de se laisser lire : permission révoquée, fournisseur
/// indisponible.
class _FailingContactRepository implements ContactRepository {
  int attempts = 0;

  @override
  Future<List<Contact>> listAll() async {
    attempts++;
    throw StateError('permission refusée');
  }
}

void main() {
  group('ContactDirectoryService', () {
    test('ne lit le carnet qu\'une fois, quel que soit le nombre d\'appels', () async {
      final contacts = InMemoryContactRepository([Build.contact()]);
      final service = ContactDirectoryService(contacts);

      for (var i = 0; i < 5; i++) {
        await service.load();
      }

      expect(contacts.readCount, 1);
    });

    test('les appels simultanés partagent un seul chargement', () async {
      // Le cas du démarrage : liste, en-tête, fil et notifications demandent
      // le carnet dans la même frame.
      final contacts = InMemoryContactRepository([Build.contact()]);
      final service = ContactDirectoryService(contacts);

      await Future.wait([
        service.load(),
        service.load(),
        service.load(),
        service.load(),
      ]);

      expect(contacts.readCount, 1);
    });

    test('relit après invalidation', () async {
      final contacts = InMemoryContactRepository([Build.contact()]);
      final service = ContactDirectoryService(contacts);

      await service.load();
      service.invalidate();
      await service.load();

      expect(contacts.readCount, 2);
    });

    test('sert le carnet à jour après invalidation', () async {
      final contacts = InMemoryContactRepository([
        Build.contact(displayName: 'Camille', addresses: ['+33612345678']),
      ]);
      final service = ContactDirectoryService(contacts);
      await service.load();

      contacts.contacts.add(
        Build.contact(displayName: 'Julien', addresses: ['+33623456789']),
      );
      service.invalidate();
      final directory = await service.load();

      expect(directory.nameFor(Build.address('+33623456789')), 'Julien');
    });

    test('un échec n\'est pas mis en cache', () async {
      // Sinon une permission accordée juste après laisserait l'app avec des
      // numéros nus jusqu'au prochain retour au premier plan.
      final failing = _FailingContactRepository();
      final service = ContactDirectoryService(failing);

      final first = await service.load();
      final second = await service.load();

      expect(first.all, isEmpty);
      expect(second.all, isEmpty);
      expect(failing.attempts, 2);
    });
  });
}
