/// Nom et version du système, sans casser la cible web.
///
/// `dart:io` n'existe pas sur le web : l'importer sans condition rendrait toute
/// l'app incompilable pour `flutter run -d web-server`, alors qu'il ne s'agit
/// que de renseigner deux attributs de ressource. L'import conditionnel choisit
/// l'implémentation à la compilation — `dart:io` là où il existe, une paire de
/// constantes ailleurs.
library;

export 'platform_info_web.dart'
    if (dart.library.io) 'platform_info_io.dart';
