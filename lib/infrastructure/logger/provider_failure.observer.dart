import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messages/core/application/services/logger_application.service.dart';

/// Journalise les providers qui échouent.
///
/// ## Le trou que ça bouche
///
/// `FlutterError.onError` et `PlatformDispatcher.onError` n'attrapent que ce
/// que **personne** n'a attrapé. Or Riverpod attrape : un provider qui lève
/// range son exception dans un `AsyncError`, l'écran affiche « Erreur : … », et
/// ni l'un ni l'autre gestionnaire n'est appelé. L'utilisateur voit une panne,
/// le journal ne voit rien.
///
/// Sept écrans de l'app rendent un état d'erreur de cette façon. Une colonne
/// nulle dans le stock Telephony, un `as String` qui casse à la traduction du
/// canal, un service applicatif qui lève : tout cela finit à l'écran et nulle
/// part ailleurs. C'est ce que cet observateur rattrape.
///
/// ## Une panne, une ligne
///
/// Riverpod 3 **réessaie** un provider en échec — dix fois, en doublant le
/// délai à partir de 200 ms. Journaliser chaque `providerDidFail` produirait
/// onze lignes identiques pour une seule panne, et rendrait un tableau de bord
/// illisible.
///
/// D'où le comptage : la **première** défaillance d'un provider est
/// journalisée avec son exception, les suivantes sont muettes et comptées.
/// Quand le provider finit par rendre une valeur, `provider.recovered` dit
/// combien de tentatives il aura fallu — ou rien du tout s'il n'y arrive
/// jamais, ce qui est précisément le cas où une seule ligne suffit.
///
/// Contrepartie assumée : deux erreurs *différentes* qui se succèdent sur le
/// même provider n'en montrent qu'une. Le compteur dit qu'il s'en est passé
/// d'autres.
final class LoggingProviderObserver extends ProviderObserver {
  /// Résolu à l'appel, pas à la construction : l'observateur est passé au
  /// `ProviderContainer` qui héberge le logger — il ne peut donc pas le tenir
  /// avant que le conteneur existe.
  final LoggerApplicationService Function() _resolveLogger;

  /// Échecs consécutifs par provider, remis à zéro dès qu'il rend une valeur.
  final Map<String, int> _failures = {};

  /// Empêche la boucle : un échec survenu *pendant* qu'on journalise un échec
  /// (le logger lui-même, ou l'une de ses dépendances) ne se rejournalise pas.
  bool _reporting = false;

  LoggingProviderObserver(this._resolveLogger);

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name = _nameOf(context);
    final count = (_failures[name] ?? 0) + 1;
    _failures[name] = count;
    // Les tentatives suivantes sont le même incident : elles se comptent, elles
    // ne se racontent pas.
    if (count > 1) return;
    _report(
      (logger) => logger.error(
        'provider.failed',
        attrs: {'provider.name': name},
        error: error,
        stack: stackTrace,
      ),
    );
  }

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    // `value` est nul quand le provider a levé à l'initialisation :
    // `providerDidFail` s'en charge, il n'y a pas de reprise à annoncer.
    if (value != null) _recovered(context);
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue != null) _recovered(context);
  }

  void _recovered(ProviderObserverContext context) {
    final name = _nameOf(context);
    final failures = _failures.remove(name);
    if (failures == null) return;
    _report(
      (logger) => logger.info(
        'provider.recovered',
        attrs: {'provider.name': name, 'provider.failures': failures},
      ),
    );
  }

  /// Le nom généré (`conversationProvider`), et non l'instance : une famille
  /// indexée par identifiant de fil donnerait autant de valeurs distinctes que
  /// de conversations.
  String _nameOf(ProviderObserverContext context) =>
      context.provider.name ?? context.provider.runtimeType.toString();

  void _report(void Function(LoggerApplicationService) emit) {
    if (_reporting) return;
    _reporting = true;
    try {
      emit(_resolveLogger());
    } catch (_) {
      // Le contrat de LoggerService interdit de lever, mais un résolveur qui
      // échouerait ne doit pas faire tomber Riverpod par la bande.
    } finally {
      _reporting = false;
    }
  }
}
