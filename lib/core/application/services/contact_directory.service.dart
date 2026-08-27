import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/services/contact.repository.dart';

/// Index adresse → contact, construit une fois puis interrogé en O(1).
///
/// C'est le pendant applicatif de ce que fait Android en joignant
/// `content://sms` à `ContactsContract` : le stock SMS ne connaît que des
/// numéros, l'affichage veut des noms.
class ContactDirectory {
  final Map<String, Contact> _byAddressKey;
  final List<Contact> all;

  ContactDirectory._(this._byAddressKey, this.all);

  static final empty = ContactDirectory._(const {}, const []);

  factory ContactDirectory.from(List<Contact> contacts) {
    final index = <String, Contact>{};
    for (final contact in contacts) {
      for (final address in contact.addresses) {
        // Premier arrivé, premier servi : deux fiches partageant un numéro sont
        // rares, et l'ordre du carnet est déjà l'ordre d'affichage.
        index.putIfAbsent(address.key, () => contact);
      }
    }
    return ContactDirectory._(index, List.unmodifiable(contacts));
  }

  Contact? lookup(Address address) => _byAddressKey[address.key];

  /// Nom affichable d'une adresse : le contact s'il existe, sinon le numéro
  /// formaté (ou l'expéditeur alphanumérique tel quel).
  String nameFor(Address address) => lookup(address)?.displayName ?? address.display;

  /// Titre d'un fil : « Alice », « Alice, Bob » ou « 06 12 34 56 78 ».
  String titleFor(List<Address> addresses) =>
      addresses.map(nameFor).join(', ');

  /// Graine de couleur d'avatar : le nom du contact quand il existe, pour que
  /// la pastille suive le contact même si le fil utilise un autre de ses
  /// numéros.
  String colorSeedFor(List<Address> addresses) {
    if (addresses.isEmpty) return '';
    final first = addresses.first;
    return lookup(first)?.displayName ?? first.key;
  }
}

/// Charge le carnet d'adresses et en fait un [ContactDirectory], **une fois**.
///
/// Le carnet est lu intégralement, vignettes comprises : sur un appareil
/// ordinaire (cinq cents fiches) cela prend le gros d'une seconde. Or sept
/// endroits en ont besoin — la liste des fils, l'en-tête d'une conversation, le
/// fil lui-même, le sélecteur de contacts, la synchro des notifications — et
/// plusieurs se déclenchent ensemble au démarrage puis à chaque changement du
/// stock. Sans mémoire, l'app relisait le carnet cinq fois pour afficher un
/// écran.
///
/// C'est la **promesse** qui est mémorisée, pas sa valeur : les appels
/// simultanés du démarrage partagent alors un seul chargement au lieu d'en
/// lancer chacun un.
///
/// Le carnet n'est pas relu tout seul — c'est [invalidate] qui décide, au
/// retour au premier plan et après l'octroi de la permission Contacts. Un
/// contact ajouté pendant que l'app est à l'écran ne sera donc vu qu'ensuite,
/// ce qui est le compromis qu'on préfère à une seconde de blocage par écran.
class ContactDirectoryService {
  final ContactRepository _contacts;
  final LoggerApplicationService _logger;

  Future<ContactDirectory>? _pending;

  ContactDirectoryService(
    this._contacts, {
    required LoggerApplicationService logger,
  }) : _logger = logger;

  Future<ContactDirectory> load() => _pending ??= _read();

  /// Oublie le carnet en mémoire : la prochaine lecture repartira du système.
  void invalidate() => _pending = null;

  /// Une permission refusée ou un carnet indisponible ne doit pas casser la
  /// liste des conversations : on retombe sur un annuaire vide, et l'UI affiche
  /// les numéros bruts.
  Future<ContactDirectory> _read() async {
    final started = DateTime.now();
    try {
      final directory = ContactDirectory.from(await _contacts.listAll());
      // Le coût de la lecture est le seul argument du cache : le mesurer, c'est
      // pouvoir dire si l'invalidation au retour au premier plan reste tenable
      // sur un vrai carnet.
      await _logger.info(
        'contacts.loaded',
        attrs: {
          'contacts.count': directory.all.length,
          'duration_ms': DateTime.now().difference(started).inMilliseconds,
        },
      );
      return directory;
    } catch (e, stack) {
      // Un échec ne se garde pas : la permission peut être accordée juste
      // après, et l'app resterait sinon avec des numéros nus jusqu'au prochain
      // retour au premier plan.
      _pending = null;
      // Le repli est silencieux à l'écran — des numéros au lieu des noms, ce
      // qu'on prend facilement pour un carnet vide plutôt que pour une panne.
      await _logger.warn(
        'contacts.load_failed',
        error: e,
        stack: stack,
      );
      return ContactDirectory.empty;
    }
  }
}
