import 'dart:developer' as developer;

import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/core/domain/services/logger.service.dart';

/// [LoggerService] qui écrit dans la console de dev via le `log()` de
/// `dart:developer`.
///
/// Utilisé :
/// - dans tout build non-release, comme puits principal ;
/// - comme une branche de [CompositeLoggerService] quand plusieurs puits
///   coexistent.
///
/// La sortie est une ligne par enregistrement : `message k=v k=v …` suivie
/// d'une stacktrace si présente. Pas cher et grep-friendly.
///
/// Pas de tampon — `flush()` est un no-op.
class ConsoleLoggerService implements LoggerService {
  /// Préfixe optionnel ajouté devant le message. Utile pour distinguer les
  /// enregistrements partis vers un autre puits quand ce service est emballé
  /// dans un [CompositeLoggerService].
  final String? prefix;

  /// Nom de logger `dart:developer`. Apparaît comme catégorie dans la vue
  /// Logging de Flutter DevTools.
  final String name;

  const ConsoleLoggerService({this.prefix, this.name = 'messages'});

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    final buf = StringBuffer();
    if (prefix != null) buf.write('$prefix ');
    buf.write(message);
    if (attributes.isNotEmpty) {
      buf.write(' ');
      buf.writeAll(
        attributes.entries.map((e) => '${e.key}=${_format(e.value)}'),
        ' ',
      );
    }
    developer.log(
      buf.toString(),
      name: name,
      level: level.otelSeverityNumber * 100, // dart:developer attend 0..2000
      error: error,
      stackTrace: stack,
    );
  }

  @override
  Future<void> flush() async {}

  String _format(Object? v) {
    if (v == null) return 'null';
    if (v is String) {
      // Met entre guillemets seulement si la valeur contient un espace, sinon
      // la ligne reste maximalement grep-friendly.
      return v.contains(RegExp(r'\s')) ? '"$v"' : v;
    }
    return v.toString();
  }
}
