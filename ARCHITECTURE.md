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
- Un **vocal** ne se lit pas, il s'écoute : sa bulle porte un lecteur
  (bouton, piste pointillée, durée) et non la ligne « nom + poids » d'un PDF.
  La durée annoncée avant lecture ne vient d'aucune colonne — rien dans
  `content://mms/part` ne la porte : elle est **mesurée** au décodeur
  (`MediaMetadataRetriever`) à la lecture des parties, puis retenue par `_id`,
  le contenu d'une partie ne changeant jamais. Sans ce cache, rouvrir un fil de
  vingt vocaux les remesurerait tous à chaque rafraîchissement.
- La **réception** de MMS n'est pas gérée : `WAP_PUSH_DELIVER` ne porte qu'une
  notification de dépôt à décoder puis à télécharger auprès du MMSC. Ce qui est
  déjà dans `content://mms` s'affiche, en revanche.

## Écouter un vocal : un seul lecteur, et il vit côté natif

Le port `AudioPlayerService` ne rend pas un lecteur par bulle mais **un état de
lecture unique**, que chaque bulle reconnaît — ou non — comme le sien. Deux
vocaux superposés ne s'écoutent pas, et le `MediaPlayer` d'Android n'existe de
toute façon qu'en un exemplaire : lancer un vocal arrête le précédent, c'est une
règle du port et non une précaution de l'appelant.

- `AudioBridge` a **son propre canal** (`fr.dtfh.messages/audio`), séparé de
  `SmsBridge` : celui-ci sert le `ContentProvider` sur un fil dédié, alors qu'un
  `MediaPlayer` vit sur le fil principal, où son `Looper` livre les rappels de
  préparation et de fin.
- Les **octets ne traversent pas le canal**, ici non plus : le natif ouvre
  directement `content://mms/part/<id>`.
- La position est **lue dans le lecteur** dix fois par seconde et poussée vers
  Dart. Une horloge côté Dart dériverait de la lecture réelle — silence en tête
  de fichier, décodage plus lent — et le curseur finirait par mentir.
- Le lecteur demande le **focus audio** en transitoire : un vocal par-dessus de
  la musique ne s'entend pas. Il le rend à la pause, et se suspend quand on le
  lui reprend.
- La **silhouette** du son (les barres de la piste) a son propre port,
  `AudioWaveformService` : lire et mesurer n'ont ni le même coût ni le même
  moment. La lecture suit un geste ; la mesure demande de décoder tout le
  fichier (`MediaExtractor` + `MediaCodec` → PCM, dont on ne garde que
  l'énergie), se fait **à l'affichage de la bulle**, sur un fil à part, et se
  retient par `_id` — comme les vignettes d'image, et pour la même raison.
  Elle est **normalisée sur le maximum du fichier** : deux vocaux enregistrés à
  des volumes différents doivent se dessiner pareil, ce qu'on lit d'une forme
  d'onde est un relief, pas un volume. Un son qui ne se décode pas laisse la
  piste neutre, jamais un relief inventé.
- Hors Android, `InMemoryAudioPlayerService` n'émet aucun son : il **avance**.
  C'est tout ce dont la démo et les tests ont besoin — que la bulle bascule en
  pause, que le curseur progresse, qu'un second vocal arrête le premier. De
  même, `InMemoryAudioWaveformService` ne décode rien : il dessine une
  silhouette **stable**, tirée de l'identifiant.
- Le provider du lecteur est `keepAlive`, celui du flux ne l'est pas : quitter
  le fil coupe l'écoute du flux, pas le son.

## Observabilité : Signoz, et de quoi lire une panne à distance

Un client SMS ne se débogue pas depuis un bureau : le stock est celui du
téléphone, le rôle d'app par défaut aussi, et l'opérateur n'est pas le nôtre.
L'app raconte donc ce qu'elle fait, et l'expédie.

- **Port** `LoggerService` (Domain) : un puits, deux méthodes (`log`, `flush`),
  et l'interdiction formelle de lever — un logger en panne ne casse pas l'app
  qu'il observe. Adaptateurs dans `lib/infrastructure/logger/` : `Console`,
  `Signoz`, `Composite`, `InMemory` (tests).
- **Façade** `LoggerApplicationService` : `info`/`warn`/`error`, et surtout la
  fusion des trois couches de contexte (dynamique → statique → site d'appel).
- `SignozLoggerService` poste la charge **OTLP/HTTP** (`ExportLogsServiceRequest`
  en JSON protobuf) sur `<ingest>/v1/logs`. Écrite à la main : trente lignes de
  sérialisation contre deux paquets `opentelemetry` encore rugueux en Dart.
  Tampon en mémoire, expédié toutes les dix secondes ou par lot de cinquante,
  plafonné à cinq cents enregistrements. **Aucune reprise** :
  un lot qui ne part pas est perdu et compté (`log.dropped_total`) — une file
  de reprise empilerait des doublons au premier incident réseau.
- **Activation par `--dart-define`.** Sans `SIGNOZ_INGEST_URL`, l'app se
  contente de sa console : c'est le cas nominal en développement. Avec, un
  build debug branche les **deux** (`CompositeLoggerService`), pour qu'on voie
  dans sa propre console exactement ce qui part sur le réseau.

### Ce qui accompagne chaque ligne

| Où | Clés | Pourquoi |
|---|---|---|
| Ressource (par lot) | `service.name`, `service.version`, `deployment.environment`, `os.type`, `os.version` | Découper les tableaux de bord ; la version d'OS explique la moitié des différences de comportement du stock Telephony. |
| Contexte (`AppLogContext`, par ligne) | `session.id`, `app.route`, `sms.default_app` | « Où était l'utilisateur, et l'app avait-elle le droit d'écrire ? » — ce que la ligne d'erreur ne dit jamais d'elle-même. |

`app.route` retient le **motif** (`/thread/:id`), jamais l'adresse
(`/thread/42`) : un identifiant de fil ferait une dimension à cardinalité
infinie, inutilisable en agrégat et bavarde sur qui parle à qui.

### Rien du contenu, jamais

Aucun log ne porte de texte de message ni de numéro. Ce qui part, ce sont des
**mesures** : `body.length`, `recipients.count`, `attachments.bytes`. Un journal
de production se lit par d'autres yeux que ceux du destinataire.

### Les erreurs non rattrapées : quatre filets, et un trou qui reste

Aucun filet ne suffit seul, parce que « non rattrapée » ne veut pas dire la même
chose selon qui aurait pu la rattraper.

| Filet | Attrape | Ne voit pas |
|---|---|---|
| `FlutterError.onError` | Erreurs **synchrones** du framework : build, layout, paint, assertions. | Tout ce qui est asynchrone. |
| `PlatformDispatcher.onError` | Erreurs **Dart asynchrones** qui échappent à tous les `Future`/`Stream`/zones — le filet de dernier recours. | Ce qu'un `catch` a déjà pris. Les isolats enfants (le SDK est explicite : le rappel n'est **pas** invoqué pour eux). |
| `LoggingProviderObserver` | Providers en échec. | Rien, dans son périmètre. |
| `AndroidSmsChannel._invoke` | Toute `PlatformException` du natif, avec la méthode appelée. | Ce qui casse côté Kotlin sans revenir par le canal. |

**Riverpod attrape, et c'est le piège.** Un provider qui lève range son
exception dans un `AsyncError` : l'écran affiche « Erreur : … », et ni
`FlutterError.onError` ni `PlatformDispatcher.onError` ne sont appelés — ils ne
servent que ce que *personne* n'a pris. Sept écrans rendent un état d'erreur de
cette façon. D'où `LoggingProviderObserver`, monté sur le `ProviderContainer` dès sa
construction.

Il ne journalise que la **première** défaillance consécutive d'un provider :
Riverpod 3 réessaie dix fois en doublant le délai, et onze lignes identiques
pour une panne unique rendraient un tableau de bord illisible. La reprise, elle,
dit combien de tentatives il aura fallu (`provider.recovered`).

**Ce qui reste hors de portée**, et qu'aucun ajustement Dart ne rattrapera :

- **Les crashs natifs** (JVM/Kotlin, plugins). Ils tuent l'isolate avant que le
  moindre rappel Dart s'exécute — le SDK le dit noir sur blanc : « le rappel ne
  sera pas appelé pour les exceptions qui font terminer la VM ou le processus
  avant qu'il puisse l'être ». Il faudrait Crashlytics ou Sentry.
- **Le tampon qui meurt avec le processus.** Mitigé, pas résolu : un
  enregistrement de niveau `error` déclenche une expédition **immédiate**, sans
  attendre le lot ni le timer. Une erreur non rattrapée précède souvent de peu
  un processus qui meurt ; dix secondes d'attente suffiraient à la perdre.
- **La toute première fraction de `main()`** — la construction du conteneur et
  du logger lui-même. Le reste du démarrage est sous `try` (`app.start_failed`,
  suivi d'un `flush()` : il n'y aura pas de session suivante pour le raconter).

`PlatformDispatcher.onError` rend `true` : l'app **survit** à l'erreur au lieu
de laisser le repli de la plateforme décider. Conséquence à connaître — ce
`true` supprime aussi l'affichage de secours, et `developer.log` ne va qu'au
service VM. En build debug, `ConsoleLoggerService` double donc les `warn` et
`error` par `debugPrint`, sans quoi une session au terminal serait aveugle :
l'erreur est enregistrée, et rien ne l'imprime.

### Les replis silencieux

Ceux qui ne cassent aucun écran et qu'on prend pour un comportement normal :
carnet d'adresses illisible (`contacts.load_failed` → des numéros nus), limite
MMS non publiée (`mms.limits_fallback` → des photos plus dégradées que
nécessaire), préférences corrompues (`preferences.decode_failed` → tous les
épinglages disparus), flux natif mort (`sms.stream_failed` → une liste qui cesse
de se rafraîchir).

### Le vidage du tampon au bon moment

`app.paused` / `app.hidden` / `app.detached` appellent `flush()`. Sans cela, les
dix dernières secondes avant que le processus meure — précisément celles qui
expliquent pourquoi il est mort — ne partiraient jamais.

Une limite connue : la cible **macOS** de démonstration n'a pas l'entitlement
`com.apple.security.network.client`, l'envoi y échoue donc (visiblement, dans la
console de dev). Sans effet sur Android, où `INTERNET` est déclarée.

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
