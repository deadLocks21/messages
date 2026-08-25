import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/core/domain/services/logger.service.dart';

/// Façade ergonomique au-dessus d'un [LoggerService].
///
/// Deux raisons d'existence plutôt que d'utiliser [LoggerService] directement :
///
/// 1. **Sucre syntaxique** — `logger.info('foo')` se lit mieux que
///    `logger.log(LogLevel.info, 'foo')` et garde le code des usecases propre.
/// 2. **Propagation de contexte** — chaque enregistrement émis est enrichi
///    d'un sac d'attributs contextuels fusionné avec ce que fournit l'appelant.
///    Les sites d'appel ne portent que les clés métier ; le contexte
///    transverse est centralisé ici.
///
/// ## Trois couches de contexte
///
/// À l'émission, les attributs sont fusionnés dans cet ordre (les couches
/// suivantes l'emportent en cas de collision de clé) :
///
/// 1. **Contexte dynamique** — produit par [resolveContext], un callback qui
///    retourne les attributs d'identité *courants* (session, device, user…).
///    Réévalué à chaque émission pour que l'instance de logger reste stable au
///    fil des transitions d'état. Câblé par le provider ; la couche
///    application elle-même reste sans dépendance à Riverpod.
/// 2. **Contexte statique** — attributs attachés via [withContext], pour
///    cadrer tous les logs d'une unité de travail (ex. une session de synchro
///    qui tague chaque log avec `sync.id`).
/// 3. **Attributs du site d'appel** — ce que l'appelant passe à `info`/`error`…
///    Les plus spécifiques, l'emportent toujours.
class LoggerApplicationService {
  final LoggerService _logger;
  final Map<String, Object?> _staticContext;
  final Map<String, Object?> Function()? _resolveContext;

  const LoggerApplicationService(
    this._logger, {
    Map<String, Object?> context = const {},
    Map<String, Object?> Function()? resolveContext,
  })  : _staticContext = context,
        _resolveContext = resolveContext;

  /// Retourne une nouvelle façade qui ajoute [extra] au contexte statique
  /// courant. Le [resolveContext] dynamique est préservé tel quel.
  LoggerApplicationService withContext(Map<String, Object?> extra) {
    if (extra.isEmpty) return this;
    return LoggerApplicationService(
      _logger,
      context: {..._staticContext, ...extra},
      resolveContext: _resolveContext,
    );
  }

  Future<void> debug(String message, {Map<String, Object?> attrs = const {}}) =>
      _emit(LogLevel.debug, message, attrs: attrs);

  Future<void> info(String message, {Map<String, Object?> attrs = const {}}) =>
      _emit(LogLevel.info, message, attrs: attrs);

  Future<void> warn(
    String message, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) =>
      _emit(LogLevel.warn, message, attrs: attrs, error: error, stack: stack);

  Future<void> error(
    String message, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) =>
      _emit(LogLevel.error, message, attrs: attrs, error: error, stack: stack);

  /// Vide le service sous-jacent. À appeler depuis les hooks de cycle de vie
  /// (pause / destruction) pour que le tampon en cours parte avant que l'OS
  /// ne suspende le process.
  Future<void> flush() => _logger.flush();

  Future<void> _emit(
    LogLevel level,
    String message, {
    required Map<String, Object?> attrs,
    Object? error,
    StackTrace? stack,
  }) {
    // Une exception du résolveur est avalée : l'identité ne doit jamais
    // sacrifier un log.
    Map<String, Object?> dynamic_;
    try {
      dynamic_ = _resolveContext?.call() ?? const {};
    } catch (_) {
      dynamic_ = const {};
    }
    final merged = (dynamic_.isEmpty && _staticContext.isEmpty && attrs.isEmpty)
        ? const <String, Object?>{}
        : <String, Object?>{...dynamic_, ..._staticContext, ...attrs};
    return _logger.log(
      level,
      message,
      attributes: merged,
      error: error,
      stack: stack,
    );
  }
}
