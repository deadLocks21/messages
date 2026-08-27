import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/providers/sms_access.provider.dart';
import 'package:messages/ui/pages/archived/archived.page.dart';
import 'package:messages/ui/pages/conversation/conversation.page.dart';
import 'package:messages/ui/pages/conversations/conversations.page.dart';
import 'package:messages/ui/pages/new_conversation/new_conversation.page.dart';
import 'package:messages/ui/pages/search/search.page.dart';
import 'package:messages/ui/pages/settings/settings.page.dart';
import 'package:messages/ui/pages/welcome/welcome.page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const welcome = '/welcome';
  static const conversations = '/';
  static const archived = '/archived';
  static const search = '/search';
  static const newConversation = '/new';
  static const settings = '/settings';
  static String thread(String id) => '/thread/$id';
}

/// Router unique. Le `redirect` est piloté par l'accès aux SMS : sans droit de
/// lecture, il n'y a rien à afficher d'autre que l'écran d'accueil.
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(smsAccessControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = _buildRouter(ref, refresh);
  _traceNavigation(ref, router);
  return router;
}

/// Note l'écran affiché, sur chaque ligne de log et à chaque changement.
///
/// Deux usages distincts et tous deux nécessaires : `app.route` en attribut de
/// contexte répond à « où était l'utilisateur quand ça a cassé ? », que la
/// ligne d'erreur ne dit jamais d'elle-même ; l'événement `app.route` répond à
/// « comment y est-il arrivé ? », en laissant le chemin parcouru avant la
/// panne.
///
/// C'est le **motif** de route (`/thread/:id`) qui est retenu, pas l'adresse
/// (`/thread/42`) : un identifiant de fil ferait de cet attribut une dimension
/// à cardinalité infinie, inutilisable en agrégat et bavarde sur qui parle à
/// qui.
void _traceNavigation(Ref ref, GoRouter router) {
  final context = ref.read(appLogContextProvider);
  final logger = ref.read(loggerProvider);

  void onChanged() {
    // `state` lève tant que le délégué n'a pas de configuration : au tout
    // premier appel, il n'y a simplement rien à noter.
    final String? route;
    try {
      route = router.state.fullPath;
    } catch (_) {
      return;
    }
    if (route == null || route == context.route) return;
    final previous = context.route;
    context.route = route;
    logger.info(
      'app.route',
      attrs: {'app.route_from': ?previous},
    );
  }

  router.routerDelegate.addListener(onChanged);
  ref.onDispose(() => router.routerDelegate.removeListener(onChanged));
  onChanged();
}

GoRouter _buildRouter(Ref ref, ValueNotifier<int> refresh) {
  return GoRouter(
    initialLocation: AppRoutes.conversations,
    refreshListenable: refresh,
    redirect: (context, goState) {
      final access = ref.read(smsAccessControllerProvider).value;
      // Autorisations pas encore résolues : on ne déplace personne. `main`
      // attend cette première lecture, ce cas n'arrive donc qu'après une
      // invalidation.
      if (access == null) return null;

      final loc = goState.matchedLocation;
      if (!access.canBrowse) {
        return loc == AppRoutes.welcome ? null : AppRoutes.welcome;
      }
      return loc == AppRoutes.welcome ? AppRoutes.conversations : null;
    },
    routes: [
      GoRoute(path: AppRoutes.welcome, builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: AppRoutes.conversations,
        builder: (_, _) => const ConversationsPage(),
      ),
      GoRoute(path: AppRoutes.archived, builder: (_, _) => const ArchivedPage()),
      GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchPage()),
      GoRoute(
        path: AppRoutes.newConversation,
        // `extra` porte le texte d'un message transféré, le cas échéant.
        builder: (_, st) => NewConversationPage(forwardedBody: st.extra as String?),
      ),
      GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(
        path: '/thread/:id',
        builder: (_, st) => ConversationPage(threadId: st.pathParameters['id']!),
      ),
    ],
  );
}
