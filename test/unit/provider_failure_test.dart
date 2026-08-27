import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/model/log_level.dart';
import 'package:messages/infrastructure/logger/in_memory.logger.service.dart';
import 'package:messages/infrastructure/logger/provider_failure.observer.dart';

/// Ce que Riverpod attrape, et que les gestionnaires du framework ne voient
/// donc jamais.
///
/// `FlutterError.onError` et `PlatformDispatcher.onError` ne sont appelés que
/// pour ce que **personne** n'a attrapé. Un provider qui lève est attrapé par
/// Riverpod : l'écran affiche « Erreur : … » et aucun des deux ne se déclenche.
/// C'est le trou que [LoggingProviderObserver] bouche.
void main() {
  late InMemoryLoggerService sink;
  late LoggingProviderObserver observer;

  setUp(() {
    sink = InMemoryLoggerService();
    observer = LoggingProviderObserver(
      () => LoggerApplicationService(sink),
    );
  });

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      observers: [observer],
      // Sans cela, Riverpod 3 réessaie dix fois en arrière-plan et les
      // tentatives tomberaient au milieu des assertions.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  test('un provider qui lève laisse une ligne, avec son exception', () {
    final boom = Provider<int>(
      (_) => throw const FormatException('colonne absente'),
      name: 'boomProvider',
    );

    // L'appelant attrape : c'est exactement le cas où rien d'autre ne
    // journaliserait.
    expect(() => containerWith().read(boom), throwsA(isA<Object>()));

    final record = sink.records.single;
    expect(record.message, 'provider.failed');
    expect(record.level, LogLevel.error);
    expect(record.attributes['provider.name'], 'boomProvider');
    expect(record.stack, isNotNull);
  });

  test('les tentatives suivantes se comptent, elles ne se répètent pas', () {
    var attempts = 0;
    final flaky = Provider<int>((_) {
      attempts++;
      throw StateError('encore');
    }, name: 'flakyProvider');

    final container = containerWith();
    for (var i = 0; i < 4; i++) {
      expect(() => container.read(flaky), throwsA(isA<Object>()));
      container.invalidate(flaky);
    }

    expect(attempts, 4);
    // Onze lignes identiques pour une seule panne rendraient un tableau de
    // bord illisible : c'est le premier échec qui parle.
    expect(
      sink.records.where((r) => r.message == 'provider.failed'),
      hasLength(1),
    );
  });

  test('la reprise dit combien de tentatives il aura fallu', () {
    var fail = true;
    final flaky = Provider<int>((_) {
      if (fail) throw StateError('pas encore');
      return 42;
    }, name: 'flakyProvider');

    final container = containerWith();
    expect(() => container.read(flaky), throwsA(isA<Object>()));
    container.invalidate(flaky);
    expect(() => container.read(flaky), throwsA(isA<Object>()));

    fail = false;
    container.invalidate(flaky);
    expect(container.read(flaky), 42);

    final recovered = sink.records.last;
    expect(recovered.message, 'provider.recovered');
    expect(recovered.level, LogLevel.info);
    expect(recovered.attributes['provider.failures'], 2);
  });

  test('un provider asynchrone en échec compte aussi', () async {
    final boom = FutureProvider<int>(
      (_) async => throw const FormatException('réponse illisible'),
      name: 'boomAsyncProvider',
    );

    final container = containerWith();
    await expectLater(
      container.read(boom.future),
      throwsA(isA<FormatException>()),
    );

    // Le cas des sept écrans : l'erreur est rangée dans un `AsyncError`, la
    // page en fait un widget, et sans cet observateur personne n'en saurait
    // rien.
    expect(
      sink.records.map((r) => r.message),
      contains('provider.failed'),
    );
  });

  test('un logger qui échoue ne fait pas tomber Riverpod', () {
    final exploding = LoggingProviderObserver(
      () => throw StateError('logger indisponible'),
    );
    final container = ProviderContainer(
      observers: [exploding],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    final boom = Provider<int>((_) => throw StateError('bang'));

    // Le remède ne doit pas être pire que le mal : un observateur qui lève
    // remonterait dans le provider et changerait l'erreur affichée.
    expect(() => container.read(boom), throwsA(isA<Object>()));
  });
}
