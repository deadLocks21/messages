# Architecture — messages (Flutter)

Clone de **Google Messages** (SMS/MMS Android). Architecture **hexagonale, layer-first**,
identique à `songbook/app`, `motorz/app` et `kidflix/app`.

## Dépendances

```
UI → Application → Domain ← Infrastructure
```

1. **Domain** (`lib/core/domain/`) ne dépend de personne — Dart pur.
   - ❌ Pas de Riverpod · ❌ pas de Flutter · ❌ pas de plateforme. ✅ logique métier pure.
   - `model/` : entités (champs `final`, invariants par `assert`, `copyWith`/`==`/`hashCode`
     manuels), value objects (`Address`), classes scellées + `switch` exhaustif (`SmsEvent`).
   - `services/` : interfaces de ports (`*.repository.dart`, `*.service.dart`, `*.source.dart`).
2. **Application** (`lib/core/application/`) ne dépend que de Domain — Dart pur.
   - `dtos/` : DTOs (`fromDomain`, dates ISO-8601, enums via `.name`).
     **L'UI ne manipule que des DTOs.**
   - `usecases/` : un cas d'usage = une classe `NameUseCase` (ports en dépendances).
   - `services/` : orchestration applicative (annuaire de contacts, groupement des bulles,
     recherche, couleurs d'avatar…).
3. **Infrastructure** (`lib/infrastructure/`) ne dépend que de Domain. **Seul lieu de Riverpod.**
   - Implémentations concrètes (`android.*`, `flutter_contacts.*`, `shared_preferences.*`,
     `in_memory.*`).
   - `sms/` : pont `MethodChannel`/`EventChannel` vers le `ContentProvider` Telephony
     d'Android (lecture des fils, envoi via `SmsManager`, réception via `SMS_DELIVER`).
   - `providers/` : providers Riverpod (`@riverpod`, `*.g.dart`) — assemblage des dépendances.
4. **UI** (`lib/ui/`) ne dépend que d'Application (et des interfaces Domain via providers).
   - `pages/<feature>/*.page.dart`, `widgets/*.widget.dart`, `providers/*.provider.dart`.
   - `router/` : go_router + `AppRoutes` + redirect piloté par l'état des permissions SMS.
   - `theme/` : `AppThemeData` + `GmPalette` + `AppColors` (ThemeExtension) + `context.appColors`.

## Règles

- **Imports absolus** (`package:messages/...`), jamais de `../`.
- **Modèles écrits à la main** — pas de freezed/json_serializable. `build_runner` seulement pour
  le codegen Riverpod. Lint : `flutter_lints` + `riverpod_lint`.
- Chaque interface a une impl réelle **et** une impl `InMemory*` (tests + dev/web/desktop).
- **Tests** : miroir de `lib/` avec les `InMemory*` comme doublures (pas de mockito).

## Le stock SMS est la source de vérité

Contrairement à motorz, **aucune base locale n'est tenue par l'app** : le `ContentProvider`
`content://sms` d'Android *est* le store. Conséquences :

- Toutes les **lectures** (fils, messages, recherche) passent par le provider système ; une
  autre application SMS qui écrit dans le stock est vue immédiatement.
- Les **écritures** vont au provider : `SmsManager.sendMultipartTextMessage` + insertion dans
  `content://sms/sent`, marquage lu via `content://sms`, suppression via `_id`/`thread_id`.
- L'app doit être **application SMS par défaut** pour écrire (rôle `ROLE_SMS`). Sans le rôle,
  elle reste en lecture seule et l'UI le signale.
- Les **rafraîchissements** sont événementiels : le natif pousse un `SmsEvent` sur un
  `EventChannel` (réception `SMS_DELIVER`, accusé d'envoi/remise, changement du stock) que
  l'infra transforme en invalidation de providers.
- Les seuls états **propres à l'app** (épinglage, archivage, sourdine, brouillons, thème) vivent
  dans `shared_preferences` derrière leurs propres ports.

## Entrer dans l'app par l'extérieur

Notification touchée, lien `sms:` d'un navigateur, partage « Envoyer par SMS »
d'une autre app : tout cela arrive sous forme d'`Intent` et sort du natif par le
port `ComposeRequestSource` (`initial()` pour l'intent de lancement, `requests`
pour ceux reçus à chaud). `MessagesApp` résout le fil, dépose le texte fourni
comme **brouillon** — jamais comme envoi — et pousse l'écran du fil.

## Notifications : pousser avant, pas demander pendant

Le récepteur `SMS_DELIVER` s'exécute **sans moteur Dart** la plupart du temps :
au moment de notifier, il ne peut demander à l'app ni si le fil est en sourdine,
ni comment s'appelle l'expéditeur. Ces deux informations lui sont donc poussées à
l'avance par le port `NotificationGateway` (`setMutedThreads`, `setDirectory`) et
persistées côté natif dans son propre `SharedPreferences` — jamais en lisant
celui du plugin `shared_preferences`, dont le format est un détail
d'implémentation.

- `SyncNotificationSettingsUseCase.execute()` republie tout au démarrage et à
  chaque retour au premier plan ; `publishMutedThreads()` seul suffit après un
  basculement de sourdine (inutile de relire le carnet d'adresses).
- L'annuaire est indexé par `Address.key`. `NotificationSettings.addressKey`
  côté Kotlin **doit rester aligné** sur cette normalisation, sinon plus aucun
  numéro n'est nommé.
- Le contenu affiché (`MessagingStyle`) est relu du stock au moment de notifier :
  le provider est déjà la source de vérité, l'app n'en tient pas de copie.
- Le fil affiché commence à l'**ancre** du fil — la date du message qui a ouvert
  la salve en cours, mémorisée par `SmsNotifications` dans ses propres
  préférences. Elle est reposée dès qu'aucune notification n'est affichée pour le
  fil (balayée, ouverte ou marquée comme lue) : une notification ne rejoue jamais
  d'échanges déjà vus. C'est l'état affiché qui arbitre, pas le drapeau `read` du
  provider — une notification balayée sans être lue ne doit pas ressortir au
  message suivant.

## Permissions & rôle d'app SMS par défaut

- `SmsAccess` (Domain) agrège : permissions runtime SMS, permission Contacts, rôle SMS par
  défaut. L'UI est redirigée vers `/welcome` tant que la lecture n'est pas possible.
- Le rôle par défaut est demandé via `RoleManager` (API 29+) avec repli sur l'intent
  `ACTION_CHANGE_DEFAULT` (API < 29).

## Lancer

```bash
flutter run -d <android_device>          # cible réelle (SMS)
flutter run -d macos                     # démo hors-Android : doublures InMemory
flutter test                             # unitaires + fonctionnels
dart run build_runner build --delete-conflicting-outputs
```
