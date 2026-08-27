import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/compose_request.dart';
import 'package:messages/infrastructure/logger/provider_failure.observer.dart';
import 'package:messages/infrastructure/providers/infra_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/infrastructure/providers/theme_providers.dart';
import 'package:messages/ui/providers/conversation_providers.dart';
import 'package:messages/ui/router/app_router.dart';
import 'package:messages/ui/theme/app_theme_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Container construit à la main pour pouvoir lire le logger avant `runApp` et
  // câbler les gestionnaires d'erreurs du framework.
  //
  // L'observateur est monté dès la construction : un provider qui échoue voit
  // son exception rangée dans un `AsyncError` par Riverpod, sans jamais passer
  // par les gestionnaires ci-dessous. Sans lui, sept écrans peuvent afficher
  // « Erreur : … » sans qu'aucune ligne ne parte.
  late final ProviderContainer container;
  container = ProviderContainer(
    observers: [LoggingProviderObserver(() => container.read(loggerProvider))],
  );
  final logger = container.read(loggerProvider);

  _installErrorHandlers(logger);

  // À partir d'ici tout est sous filet. Ce qui précède ne l'est pas — c'est la
  // construction du logger lui-même — mais ne fait rien qui puisse échouer.
  await _boot(container, logger);
}

/// Le démarrage proprement dit, sous `try` : `initializeDateFormatting` et la
/// première frame échouent rarement, mais quand elles échouent l'app ne
/// démarre pas *du tout*, et c'est le seul cas où l'absence de log ne se
/// rattrape jamais — il n'y aura pas de session suivante pour le raconter.
Future<void> _boot(
  ProviderContainer container,
  LoggerApplicationService logger,
) async {
  try {
    await _start(container, logger);
  } catch (e, stack) {
    await logger.error('app.start_failed', error: e, stack: stack);
    // Expédié tout de suite : le processus n'ira peut-être pas plus loin, et
    // le tampon mourrait avec lui.
    await logger.flush();
    rethrow;
  }
}

Future<void> _start(
  ProviderContainer container,
  LoggerApplicationService logger,
) async {
  // Les libellés de date sont en français partout (« hier », « ven. 22 août »).
  await initializeDateFormatting('fr_FR');

  // Les autorisations décident de l'écran de départ : les résoudre avant le
  // premier build évite un aller-retour visible par l'écran d'accueil.
  // Best-effort — une plateforme sans canal SMS ne doit pas bloquer le
  // démarrage.
  try {
    final access = await container.read(smsAccessControllerProvider.future);
    // Tracé au démarrage : c'est ce que voit l'app, et c'est la première chose
    // à comparer aux réglages Android quand elle se croit bridée à tort.
    logger.info(
      'sms.access',
      attrs: {
        'sms.read': access.canReadSms,
        'sms.send': access.canSendSms,
        'sms.contacts': access.canReadContacts,
        'sms.notify': access.canNotify,
        'sms.default_app': access.isDefaultSmsApp,
      },
    );
  } catch (e, stack) {
    logger.error('sms.access_check_failed', error: e, stack: stack);
  }

  // Le récepteur SMS notifie sans moteur Dart : il lui faut l'annuaire et les
  // fils en sourdine *avant* le premier message reçu. Best-effort — une
  // plateforme sans canal natif n'a rien à publier.
  try {
    await container.read(syncNotificationSettingsUseCaseProvider).execute();
  } catch (e, stack) {
    logger.error('notifications.sync_failed', error: e, stack: stack);
  }

  // Émis en dernier, une fois le décor connu (autorisations, rôle) : c'est la
  // ligne à laquelle on remonte pour dater le début d'une session.
  logger.info('app.started');

  runApp(
    UncontrolledProviderScope(container: container, child: const MessagesApp()),
  );
}

/// Route les erreurs Flutter/Dart non capturées vers le logger.
///
/// - [FlutterError.onError] — erreurs synchrones du framework (build, layout,
///   assertions).
/// - [PlatformDispatcher.onError] — erreurs Dart asynchrones qui échappent à
///   tous les `Future`/`Stream`/zones au-dessus.
///
/// Les crashs natifs (JVM côté Android) passent à côté des deux : ils tuent
/// l'isolate avant que l'un ou l'autre ne s'exécute.
void _installErrorHandlers(LoggerApplicationService logger) {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      'flutter.error',
      error: details.exception,
      stack: details.stack,
      attrs: {
        if (details.library != null) 'flutter.library': details.library!,
        if (details.context != null)
          'flutter.context': details.context!.toString(),
      },
    );
    // On garde le comportement par défaut (écran rouge en debug) pour ne pas
    // masquer silencieusement les erreurs pendant le développement.
    defaultOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('dart.uncaught', error: error, stack: stack);
    return true;
  };
}

class MessagesApp extends ConsumerStatefulWidget {
  const MessagesApp({super.key});

  @override
  ConsumerState<MessagesApp> createState() => _MessagesAppState();
}

class _MessagesAppState extends ConsumerState<MessagesApp>
    with WidgetsBindingObserver {
  /// Au-delà de cette absence, le carnet d'adresses est considéré comme
  /// périmé et relu au retour.
  static const _staleAfter = Duration(seconds: 30);

  /// Quand l'app est passée en arrière-plan. Null si elle n'en revient pas.
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // L'app a peut-être été lancée par une notification ou un lien `sms:` :
    // après la première frame, le routeur existe et peut recevoir la demande.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialRequest());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Le cycle de vie fait deux choses ici.
  ///
  /// La première est de rafraîchir ce qui a pu bouger pendant l'absence. La
  /// seconde est d'**expédier le tampon de logs** avant que l'OS ne suspende
  /// le processus : l'adaptateur Signoz ne vide le sien que toutes les dix
  /// secondes et ne rejoue jamais un lot perdu. Or les dernières secondes
  /// avant que l'app disparaisse sont précisément celles qui expliquent
  /// pourquoi elle a disparu — sans ce vidage, ce sont les seules à manquer.
  ///
  /// `paused` et `hidden` font le vrai travail : ils surviennent au simple
  /// passage en arrière-plan, bien avant que l'utilisateur ne balaie l'app.
  /// `detached` est au mieux-effort — la plateforme peut tuer le processus
  /// avant la fin du POST.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final logger = ref.read(loggerProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        final away = _backgroundedAt;
        _backgroundedAt = null;
        logger.info(
          'app.resumed',
          attrs: {
            if (away != null)
              'app.away_ms': DateTime.now().difference(away).inMilliseconds,
          },
        );
        // L'utilisateur a pu changer l'app SMS par défaut depuis les réglages
        // Android, et des messages ont pu arriver pendant notre absence.
        ref.read(smsAccessControllerProvider.notifier).refresh();
        // Un contact a pu être ajouté ou renommé pendant notre absence : le
        // carnet en mémoire est périmé, et c'est le seul moment où on accepte
        // d'en payer la relecture.
        //
        // Mais seulement après une vraie absence. Relire cinq cents fiches
        // coûte le gros d'une seconde ; le faire à chaque bascule punirait
        // l'aller-retour vers la galerie pour joindre une photo, alors que le
        // carnet n'a évidemment pas bougé entre-temps.
        if (away == null || DateTime.now().difference(away) > _staleAfter) {
          ref.read(contactDirectoryServiceProvider).invalidate();
        }
        ref.invalidate(conversationsProvider);
        ref.read(syncNotificationSettingsUseCaseProvider).execute();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
        logger.info('app.backgrounded', attrs: {'app.state': state.name});
        logger.flush();
      case AppLifecycleState.detached:
        logger.info('app.detached');
        logger.flush();
      case AppLifecycleState.inactive:
        // Transitoire (volet de notifications tiré, appel entrant) : ni une
        // absence, ni un moment où le processus risque de mourir.
        break;
    }
  }

  Future<void> _openInitialRequest() async {
    final request = await ref.read(composeRequestSourceProvider).initial();
    if (request != null) await _open(request);
  }

  /// Ouvre le fil visé par une demande extérieure, en déposant le texte
  /// pré-rempli comme brouillon — rien n'est envoyé sans validation.
  ///
  /// Entrée par l'extérieur : notification touchée, lien `sms:`, partage d'une
  /// autre app. Un fil qui s'ouvre au mauvais endroit ne se distingue sinon pas
  /// d'un utilisateur qui aurait tapé la mauvaise ligne — d'où la trace.
  Future<void> _open(ComposeRequest request) async {
    final router = ref.read(goRouterProvider);
    final recipient = request.recipient;
    ref.read(loggerProvider).info(
      'compose.opened',
      attrs: {
        'compose.has_recipient': recipient != null,
        'compose.has_body': request.body?.isNotEmpty ?? false,
      },
    );
    if (recipient == null) {
      router.push(AppRoutes.newConversation, extra: request.body);
      return;
    }

    try {
      final threadId = await ref
          .read(startConversationUseCaseProvider)
          .execute([recipient.raw]);
      final body = request.body;
      if (body != null && body.isNotEmpty) {
        await ref.read(saveDraftUseCaseProvider).execute(threadId, body);
        ref.invalidate(draftProvider(threadId));
      }
      router.push(AppRoutes.thread(threadId));
    } on SmsException catch (e) {
      ref
          .read(loggerProvider)
          .warn('compose.open_failed', attrs: {'reason': e.message});
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider).value;

    // Une demande arrivée pendant que l'app tourne : notification touchée
    // depuis un autre écran, partage d'une autre application.
    ref.listen(composeRequestsProvider, (_, next) {
      final request = next.value;
      if (request != null) _open(request);
    });

    return MaterialApp.router(
      title: 'Messages',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(goRouterProvider),
      theme: AppThemeData.buildLightTheme(),
      darkTheme: AppThemeData.buildDarkTheme(),
      themeMode: themeMode == null
          ? ThemeMode.system
          : AppThemeData.toFlutterThemeMode(themeMode),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
