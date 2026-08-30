# messages-app

Clone de **Google Messages** — client SMS Android, écrit en Flutter.

Conventions reprises de `songbook/app`, `motorz/app` et `kidflix/app` : archi
**hexagonale layer-first** (`core/domain`, `core/application`, `infrastructure`,
`ui`), Riverpod 3 + codegen, modèles écrits à la main, `go_router`, imports
absolus, `InMemory*` comme doublures de test. Détail dans
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Ce que fait l'app

| | |
|---|---|
| **Conversations** | Liste triée (épinglés d'abord), pastille de non-lus, recherche et ses filtres (« Non lues », « Archivées »), archives, mode sélection multiple (épingler, archiver, sourdine, marquer lu, supprimer). |
| **Fil** | Bulles groupées à la Google Messages, séparateurs de date, états `Envoi… / Envoyé / Distribué / Non distribué`, appui long (copier, transférer, supprimer, détails, réessayer), appel du correspondant. |
| **Envoi** | SMS simple et multi-parties (compteur de segments), envoi optimiste, accusés de dépôt et de remise, renvoi d'un échec. |
| **Pièces jointes** | Galerie, appareil photo, fichiers, fiche de contact ; compression des images au plafond de l'opérateur, une pièce jointe par MMS, image rouverte en grand, PDF et vidéos confiés au système. |
| **Vocaux** | Enregistrement depuis le champ de rédaction (panneau à trois états : invitation, enregistrement avec compteur et piste, relecture), durée bornée au budget MMS de l'opérateur, suppression du bruit annoncée quand l'appareil la sert, envoi en MMS `audio/amr`. |
| **Réception** | `SMS_DELIVER` → écriture dans le stock + notification + rafraîchissement live de l'UI. |
| **Rédaction** | Sélecteur de contacts (nom ou numéro), numéro libre, brouillons persistés, transfert d'un message. |
| **Notifications** | `MessagingStyle` (fil des derniers échanges, nom du contact), **réponse directe** et **marquer comme lu** depuis le volet, groupement + résumé, sourdine par fil respectée, annulation quand le fil est lu dans l'app. |
| **Système** | Demande des permissions (SMS, contacts, notifications) puis du rôle **application SMS par défaut**, ouverture depuis une notification ou un lien `sms:`, thème clair/sombre. |
| **Journalisation** | Logs applicatifs et erreurs expédiés à **Signoz** en OTLP/HTTP, avec l'écran courant et l'état du rôle d'app par défaut sur chaque ligne. |

Reste à faire : notifier les **échecs d'envoi** (« Message non envoyé »), et
couvrir le Kotlin par des tests instrumentés — `flutter_test` ne l'atteint pas.

Hors périmètre : le **RCS** ; la **réception** de MMS — les composants exigés
par le rôle d'app par défaut existent (`MmsDeliverReceiver`,
`HeadlessSmsSendService`), mais un MMS entrant n'est pas téléchargé auprès du
MMSC ; et le **maintien-appuyé** sur le bouton du vocal (« Faire glisser pour
annuler »), raccourci vers le même enregistrement que le panneau couvre déjà
entièrement.

## Le stock SMS est la source de vérité

Pas de base locale : le `ContentProvider` Telephony *est* le store. Le pont natif
(`android/app/src/main/kotlin/fr/dtfh/messages/`) expose `content://sms` par
`MethodChannel`, et pousse réceptions et accusés par `EventChannel` — que l'infra
transforme en invalidation de providers, d'où une liste qui se met à jour sans
qu'on tire dessus.

Hors Android (macOS, web, tests), l'app tourne sur `InMemorySmsStore` pré-rempli
par `DemoSeed` : l'UI reste développable sans téléphone.

## Développer

```bash
flutter run -d <android_device>    # cible réelle (SMS)
flutter run -d macos               # démo sur doublures InMemory
flutter test                       # unitaires + fonctionnels
flutter analyze
dart run build_runner build        # providers Riverpod (*.g.dart)
```

### Envoyer les logs à Signoz

Rien n'est expédié tant que `SIGNOZ_INGEST_URL` est vide : par défaut, l'app se
contente de la console de dev. Pour brancher Signoz :

```bash
flutter run -d <android_device> \
  --dart-define=SIGNOZ_INGEST_URL=https://ingest.<région>.signoz.cloud:443/v1/logs \
  --dart-define=SIGNOZ_INGESTION_KEY=<clé> \
  --dart-define=SIGNOZ_ENV=development \
  --dart-define=APP_VERSION=$(git describe --tags --always)
```

| `--dart-define` | Effet |
|---|---|
| `SIGNOZ_INGEST_URL` | Point d'entrée OTLP/HTTP complet. **Vide → Signoz désactivé.** |
| `SIGNOZ_INGESTION_KEY` | En-tête `signoz-access-token`. À omettre pour un collecteur auto-hébergé sans authentification. |
| `SIGNOZ_ENV` | `deployment.environment`. Défaut : `production` en release, `development` sinon. |
| `APP_VERSION` | `service.version`. Défaut `dev`, pour qu'un build local non configuré se voie dans Signoz. |

Sur un collecteur local, viser `http://10.0.2.2:4318/v1/logs` depuis l'émulateur
Android (`10.0.2.2` est la machine hôte vue du téléphone virtuel).

En build **debug** avec Signoz branché, les enregistrements sont doublés dans la
console, préfixés `[→signoz]` : ce qu'on lit localement est exactement ce qui
part. Les échecs d'expédition (clé invalide, collecteur injoignable) sont
signalés sous le nom `messages.logger` — la seule façon de voir un silence.

Dans Signoz, l'app se trouve sous `service.name = messages`. Quelques
enregistrements pour s'orienter :

| Nom | Quand |
|---|---|
| `app.started`, `app.route`, `app.backgrounded` | Démarrage, navigation, mises en arrière-plan. |
| `message.send`, `message.send_failed`, `message.resent` | Un envoi, son transport (`sms`/`mms`) et son sort. |
| `sms.platform_error`, `sms.channel_missing` | Le natif a refusé — avec la méthode appelée et son code d'erreur. |
| `sms.default_app_refused`, `sms.default_app_changed` | L'app n'a pas (ou plus) le droit d'écrire dans le stock. |
| `attachment.rejected`, `attachment.compressed`, `mms.limits_fallback` | Pourquoi une photo est refusée, ou part plus dégradée que prévu. |
| `voice.record_started`, `voice.recorded`, `voice.record_discarded`, `voice.record_refused` | Un enregistrement, sa durée, son poids — ou le micro qu'on n'a pas obtenu. |
| `flutter.error`, `dart.uncaught` | Ce que personne n'avait attrapé. |
| `provider.failed`, `provider.recovered` | Un provider en échec — l'écran affiche « Erreur : … », et Riverpod ayant attrapé, aucun des deux gestionnaires ci-dessus ne se déclenche. |
| `app.start_failed` | Le démarrage n'est pas allé au bout. Expédié immédiatement : il n'y aura pas de session suivante pour le raconter. |

Aucun de ces enregistrements ne porte de texte de message ni de numéro : ce sont
des mesures (`body.length`, `recipients.count`, `attachments.bytes`).

Le **micro** ne figure pas dans cette salve : il est demandé au moment du
premier enregistrement, là où l'utilisateur comprend pourquoi. Une application
de SMS n'a pas à réclamer un micro à qui n'enverra jamais de vocal.

Sur un téléphone, l'app doit être définie **application SMS par défaut** pour
envoyer, recevoir et écrire dans le stock : l'écran d'accueil enchaîne les deux
demandes (permissions runtime, puis rôle `ROLE_SMS`). Sans le rôle, elle reste
en lecture seule et le signale par un bandeau.

## Tests

`test/unit/` (domaine, services applicatifs, cas d'usage, traduction du canal
natif, charge OTLP expédiée à Signoz et enregistrements sur lesquels on compte
pour comprendre un envoi qui échoue) et `test/functional/` (écrans montés sur un `TestDevice`, plus un
parcours de bout en bout avec le routeur). Pas de mockito : les doublures sont
les implémentations `InMemory*` de production pour les plateformes non-Android.
