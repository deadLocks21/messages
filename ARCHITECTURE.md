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
   - `attachments/` : sélecteurs de pièces jointes et lecture de leurs octets
     (`android.*` par le pont natif, `in_memory.*` pour la démo et les tests).
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

## Pièces jointes : le SMS ne les porte pas, le MMS oui

Joindre une photo change le **transport**, pas seulement le contenu. Un message
qui porte des pièces jointes part en MMS : PDU `M-Send.req` encodé à la main
(`MmsPdu.kt` — Android n'expose aucune API publique pour cela) et poussé vers le
MMSC par `SmsManager.sendMultimediaMessage`, puis écrit dans `content://mms`.
Un message sans pièce jointe suit la voie SMS d'avant, inchangée.

- C'est la **présence de pièces jointes** qui décide, jamais l'appelant :
  `MessageRepository.send` prend une liste, et l'infrastructure aiguille.
- Un MMS n'est pas une ligne mais trois tables : l'enveloppe (`content://mms`),
  les adresses (`.../addr`) et le contenu (`content://mms/part`) — le texte y
  est une *partie* comme une autre. `MmsStore` les recompose, `SmsStore`
  fusionne le résultat avec les SMS ; les identifiants MMS sont préfixés
  `mms:` pour ne pas collisionner avec les `_id` de la table SMS.
- Les dates du provider MMS sont en **secondes**, celles des SMS en
  millisecondes.
- Les **octets ne traversent pas le canal** avec les messages : une pièce jointe
  se décrit (type, nom, poids, dimensions) et ne se lit qu'à l'affichage de sa
  vignette, une par une.
- **Une pièce jointe par message.** Le budget d'un MMS est fixe : regrouper
  trois photos partagerait ce budget et diviserait leur qualité par trois.
  Elles partent donc en trois MMS, chacune disposant du budget entier. Le prix
  est assumé — le MMS est souvent facturé à l'unité. La légende accompagne le
  premier message, une seule fois.
- La taille est contrôlée **à la sélection**, pas à l'envoi : un refus du MMSC
  arriverait trop tard pour être réparable. Les images trop lourdes sont
  **allégées** (`ImageCompressor` : qualité JPEG d'abord, dimensions ensuite,
  orientation EXIF respectée) ; une vidéo ou un PDF ne s'allègent pas et sont
  refusés franchement.
- Le plafond n'est pas une constante du protocole : il est **lu** dans la
  configuration opérateur (`MmsConfig`) et mis en cache, avec repli sur les
  300 Ko d'AOSP. Attention à ce qu'il signifie — c'est la limite de *notre*
  réseau pour l'émission ; celui du destinataire a la sienne et transcodera le
  média s'il est plus strict, sans que nous en soyons informés.
- Dans une bulle, une image n'est qu'un **aperçu** : recadrée à la largeur de
  la bulle et décodée à cette taille-là. L'appui la rouvre en grand
  (`AttachmentViewerPage`) — décodée entière cette fois, zoomable, sur fond
  noir. C'est une route locale du `Navigator`, pas du `GoRouter` : un aperçu ne
  se partage pas par une URL et ne survit pas au fil qui l'a ouvert.
- La **réception** de MMS n'est pas gérée : `WAP_PUSH_DELIVER` ne porte qu'une
  notification de dépôt à décoder puis à télécharger auprès du MMSC. Ce qui est
  déjà dans `content://mms` s'affiche, en revanche.

## Le stock SMS est la source de vérité

Contrairement à motorz, **aucune base locale n'est tenue par l'app** : le `ContentProvider`
`content://sms` d'Android *est* le store. Conséquences :

- Toutes les **lectures** (fils, messages, recherche) passent par le provider système —
  `content://sms` et `content://mms` — ; une autre application SMS qui écrit dans le
  stock est vue immédiatement.
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
