import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/core/domain/services/logger.service.dart';

/// Diffuse chaque enregistrement de log vers une liste de [LoggerService].
///
/// Cas d'usage principal : brancher plusieurs puits en même temps (console de
/// dev + capture en mémoire pour un écran de diagnostic) sans que les sites
/// d'appel aient à connaître autre chose que le port [LoggerService].
///
/// Les appels aux enfants sont séquentiels (`await` chacun) — le volume est
/// assez faible pour que le fan-out parallèle soit prématuré, et les appels
/// séquentiels rendent l'ordre déterministe dans la console.
///
/// Si un enfant lève (ce qu'il ne devrait pas, d'après le contrat
/// [LoggerService], mais par prudence), l'erreur est avalée pour qu'un
/// adaptateur défaillant ne fasse pas tomber les autres.
class CompositeLoggerService implements LoggerService {
  final List<LoggerService> _children;

  CompositeLoggerService(List<LoggerService> children)
      : assert(
          children.isNotEmpty,
          'CompositeLoggerService a besoin d\'au moins un enfant',
        ),
        _children = List.unmodifiable(children);

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    for (final child in _children) {
      try {
        await child.log(
          level,
          message,
          attributes: attributes,
          error: error,
          stack: stack,
        );
      } catch (_) {
        // Avalé — un mauvais adaptateur ne doit pas faire taire les autres.
      }
    }
  }

  @override
  Future<void> flush() async {
    for (final child in _children) {
      try {
        await child.flush();
      } catch (_) {
        // Cf. ci-dessus.
      }
    }
  }
}
