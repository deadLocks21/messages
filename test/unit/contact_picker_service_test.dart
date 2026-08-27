import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/contact_picker.service.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';

import '../builders/builders.dart';
import '../helpers/test_logger.dart';

void main() {
  late InMemoryContactRepository contacts;
  late ContactPickerService service;

  setUp(() {
    contacts = InMemoryContactRepository([
      Build.contact(displayName: 'Camille Rousseau', addresses: ['0612345678']),
      Build.contact(displayName: 'Julien Marchand', addresses: ['0623456789']),
    ]);
    service = ContactPickerService(
      ContactDirectoryService(contacts, logger: testLogger()),
    );
  });

  group('ContactPickerService', () {
    test('sans requête, propose tout le carnet', () async {
      expect(await service.suggestions(), hasLength(2));
    });

    test('filtre par nom', () async {
      final suggestions = await service.suggestions(query: 'juli');

      expect(suggestions.single.displayName, 'Julien Marchand');
    });

    test('filtre par numéro', () async {
      final suggestions = await service.suggestions(query: '0623');

      expect(suggestions.single.displayName, 'Julien Marchand');
    });

    test('propose le numéro tapé s\'il est inconnu du carnet', () async {
      final suggestions = await service.suggestions(query: '0699887766');

      expect(suggestions.first.displayName, '06 99 88 77 66');
      expect(suggestions.first.addresses.single, '0699887766');
    });

    test('ne double pas un numéro déjà présent dans le carnet', () async {
      final suggestions = await service.suggestions(query: '0612345678');

      expect(suggestions, hasLength(1));
      expect(suggestions.single.displayName, 'Camille Rousseau');
    });

    test('rend une fiche pour une adresse quelconque', () async {
      expect((await service.forAddress('+33612345678')).displayName, 'Camille Rousseau');
      expect((await service.forAddress('36002')).displayName, '36002');
    });
  });
}
