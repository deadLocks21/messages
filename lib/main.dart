import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/compose_request.dart';
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

  // Les libellés de date sont en français partout (« hier », « ven. 22 août »).
  await initializeDateFormatting('fr_FR');

  // Container construit à la main pour pouvoir lire le logger avant `runApp` et
  // câbler les gestionnaires d'erreurs du framework.
  final container = ProviderContainer();
  final logger = container.read(loggerProvider);

  _installErrorHandlers(logger);

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final logger = ref.read(loggerProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        logger.info('app.resumed');
        // L'utilisateur a pu changer l'app SMS par défaut depuis les réglages
        // Android, et des messages ont pu arriver pendant notre absence.
        ref.read(smsAccessControllerProvider.notifier).refresh();
        ref.invalidate(conversationsProvider);
        // Un contact a pu être ajouté ou renommé pendant notre absence.
        ref.read(syncNotificationSettingsUseCaseProvider).execute();
      case AppLifecycleState.paused:
        logger.info('app.paused');
        logger.flush();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _openInitialRequest() async {
    final request = await ref.read(composeRequestSourceProvider).initial();
    if (request != null) await _open(request);
  }

  /// Ouvre le fil visé par une demande extérieure, en déposant le texte
  /// pré-rempli comme brouillon — rien n'est envoyé sans validation.
  Future<void> _open(ComposeRequest request) async {
    final router = ref.read(goRouterProvider);
    final recipient = request.recipient;
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
      ref.read(loggerProvider).warn('compose.open_failed', attrs: {'reason': e.message});
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
