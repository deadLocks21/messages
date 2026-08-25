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
| **Conversations** | Liste triée (épinglés d'abord), filtres « Tous / Non lus », recherche, archives, mode sélection multiple (épingler, archiver, sourdine, marquer lu, supprimer). |
| **Fil** | Bulles groupées à la Google Messages, séparateurs de date, états `Envoi… / Envoyé / Distribué / Non distribué`, appui long (copier, transférer, supprimer, détails, réessayer), appel du correspondant. |
| **Envoi** | SMS simple et multi-parties (compteur de segments), envoi optimiste, accusés de dépôt et de remise, renvoi d'un échec. |
| **Réception** | `SMS_DELIVER` → écriture dans le stock + notification + rafraîchissement live de l'UI. |
| **Rédaction** | Sélecteur de contacts (nom ou numéro), numéro libre, brouillons persistés, transfert d'un message. |
| **Notifications** | `MessagingStyle` (fil des derniers échanges, nom du contact), **réponse directe** et **marquer comme lu** depuis le volet, groupement + résumé, sourdine par fil respectée, annulation quand le fil est lu dans l'app. |
| **Système** | Demande des permissions (SMS, contacts, notifications) puis du rôle **application SMS par défaut**, ouverture depuis une notification ou un lien `sms:`, thème clair/sombre. |

Reste à faire : notifier les **échecs d'envoi** (« Message non envoyé »), et
couvrir le Kotlin par des tests instrumentés — `flutter_test` ne l'atteint pas.

Hors périmètre : **MMS** et **RCS**. Les composants Android exigés par le rôle
d'app par défaut existent (`MmsDeliverReceiver`, `HeadlessSmsSendService`), mais
les MMS ne sont ni téléchargés ni composés.

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

Sur un téléphone, l'app doit être définie **application SMS par défaut** pour
envoyer, recevoir et écrire dans le stock : l'écran d'accueil enchaîne les deux
demandes (permissions runtime, puis rôle `ROLE_SMS`). Sans le rôle, elle reste
en lecture seule et le signale par un bandeau.

## Tests

`test/unit/` (domaine, services applicatifs, cas d'usage, traduction du canal
natif) et `test/functional/` (écrans montés sur un `TestDevice`, plus un
parcours de bout en bout avec le routeur). Pas de mockito : les doublures sont
les implémentations `InMemory*` de production pour les plateformes non-Android.
