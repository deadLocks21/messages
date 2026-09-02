import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/services/contact_card.service.dart';

/// Fiche contact réelle : `ContactsContract`, via `flutter_contacts`.
///
/// Les deux appels partent en `ACTION_VIEW` / `ACTION_INSERT` vers l'app
/// Contacts. Un appareil sans app de contacts lève une `PlatformException`
/// (`ActivityNotFoundException` côté natif) : c'est le seul échec attendu, et
/// il ne doit pas remonter comme une erreur — l'appui n'aboutit simplement
/// pas, et l'écran le dit.
class FlutterContactsContactCardService implements ContactCardService {
  final LoggerApplicationService _logger;

  const FlutterContactsContactCardService({
    required LoggerApplicationService logger,
  }) : _logger = logger;

  @override
  Future<bool> open(String contactId) =>
      _launch('view', () => fc.FlutterContacts.openExternalView(contactId));

  @override
  Future<bool> create(String address) => _launch(
    'insert',
    // Le numéro seul : le carnet le remplira du nom que l'utilisateur tape.
    () => fc.FlutterContacts.openExternalInsert(
      fc.Contact()..phones = [fc.Phone(address)],
    ),
  );

  Future<bool> _launch(String intent, Future<void> Function() open) async {
    try {
      await open();
      return true;
    } on PlatformException catch (e) {
      // Sans cette ligne, un téléphone sans app de contacts ne laisse aucune
      // trace : l'utilisateur appuie, rien ne bouge, et le journal est muet.
      await _logger.warn(
        'contact_card.open_failed',
        attrs: {'contact_card.intent': intent, 'error.code': e.code},
      );
      return false;
    }
  }
}
