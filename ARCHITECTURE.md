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

## Les couleurs viennent de l'appareil, pas de l'app

Google Messages ne porte pas de palette : il porte des **tons**, appliqués aux
palettes tonales que le système tire du fond d'écran (Material You). L'app fait
pareil — c'est la seule façon qu'elle suive le thème de l'appareil au lieu
d'imposer le sien.

- `SystemPalettesBuilder` lit les **cinq palettes tonales** du système
  (`dynamic_color`, Android 12+) ; à défaut, la couleur d'accentuation du bureau
  (macOS, Windows, Linux) ; à défaut encore, elles sont **semées** sur l'ambre
  de `GmPalette` avec la recette d'Android (« tonal spot »). Une seule table de
  tons sert les trois cas.
- On ne prend pas le `ColorScheme` que `dynamic_color` sait dériver : c'est
  celui de Material 3 **2021**, où les cinq `surfaceContainer` n'existent pas
  encore et retombent tous sur la même valeur — l'app se peindrait d'un blanc
  plat là où l'originale empile fond, panneau et champs. `messagesScheme`
  reconstruit donc le schéma depuis les palettes, aux tons de la spécification.
- **`GmTones` est le relevé.** Chaque token dit dans quelle palette puiser et à
  quel ton, mesuré au pixel sur l'app d'origine (émulateur Android 16, écran de
  liste et écran de fil, clair puis sombre) :

  | Token | Palette | Clair | Sombre | Relevé |
  |---|---|---|---|---|
  | `surface` (panneau) | neutre | 97 | 5 | `#F8F5FF` / `#05092F` |
  | `background` (barres, bulles reçues, champs) | neutre | 92 | 11 | `#E6E6FF` / `#161E40` |
  | `accent` (liens, envoi, non-lus) | primaire | 40 | 80 | `#0055D5` |
  | `accentSoft` (bandeaux, puces) | primaire | 90 | 30 | `#DAE2FF` |
  | `fab` | primaire | 66 | 66 | `#789DFF` |
  | `bubbleOutgoing` | primaire | 90 | 77 | `#DAE2FF` / `#A7BAFF` |
  | `voice` (bouton du vocal) | tertiaire | 90 | 30 | `#FFD6F7` / `#DBE9A0` |
  | `panel` (enregistrement) | secondaire | 90 | 30 | `#DAE5FB` / `#F1E3D0` |
  | `record` (bouton micro) | secondaire | 40 | 80 | `#3C4279` |
  | `audioControl` (lecteur d'un vocal) | neutre variante | 63 | 45 | `#8D95D6` |

  Quatre de ces tons — ceux du **FAB**, de la **bulle envoyée** et du **lecteur
  de vocal** — ne sont pas des rôles Material standard, et c'est ce qui
  distingue l'app d'origine d'une app Material par défaut : le FAB a un ton
  médian, le même en clair et en sombre ; la bulle envoyée reste **claire à
  texte foncé** en thème sombre (t77) au lieu de basculer sur le conteneur
  sombre (t30) ; et le lecteur d'un vocal se tient à une trentaine de tons du
  fond de sa bulle, ni à son contraste ni à sa couleur. Les autres sont bien
  les rôles de la spécification, appliqués là où l'app d'origine les applique.
- Dans l'app d'origine, les barres, les bulles reçues et le champ de rédaction
  sont **exactement la même couleur** — d'où `surfaceAlt == background`. Un bloc
  posé à même le fond doit donc prendre `surface`, pas `surfaceAlt`.
- Le **bouton du message vocal** est la seule chose de l'app peinte dans la
  palette **tertiaire**, et c'est ce qui le fait repérer au bout d'un champ de
  saisie : il n'a la couleur d'aucun autre bouton — rose sur un appareil bleu,
  vert sur un appareil pêche. Les deux relevés de la table ci-dessus sont bien
  le même token sur deux appareils.
- Exception assumée : les **pastilles d'avatar** (`GmPalette.avatarSlots`) ne
  suivent pas le thème. L'app d'origine non plus : sur un appareil à palette
  bleue, elle affiche les mêmes pastilles jaune et orange. Elles servent à
  distinguer les correspondants, pas à décorer.

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
- Une image **est** la bulle : pas de fond de message derrière elle, pas de
  liseré autour. Elle prend les coins de la bulle — arrondis ou resserrés selon
  la salve, comme n'importe quelle autre. Le fond ne revient que là où il sert
  à lire : sous une légende, ou derrière un lecteur audio. L'image, elle, reste
  bord à bord et resserre ses coins du bas, le message continuant en dessous.
- Dans une bulle, une image n'est qu'un **aperçu** : recadrée à la largeur de
  la bulle et décodée à cette taille-là. L'appui la rouvre en grand
  (`AttachmentViewerPage`) — décodée entière cette fois, zoomable, sur fond
  noir. C'est une route locale du `Navigator`, pas du `GoRouter` : un aperçu ne
  se partage pas par une URL et ne survit pas au fil qui l'a ouvert.
- Un **vocal** ne se lit pas, il s'écoute : sa bulle porte un lecteur
  (bouton, curseur, durée) et non la ligne « nom + poids » d'un PDF. Le
  curseur est celui de Material 3 — gélule de 16 dp, tête de lecture en barre
  de 4 × 44, pastille de fin — et **pas** une silhouette du son : l'app
  d'origine ne dessine le relief que dans le panneau d'enregistrement, où il
  dit que le micro entend. Dans la bulle il ne dirait rien de plus.
  La durée annoncée avant lecture ne vient d'aucune colonne — rien dans
  `content://mms/part` ne la porte : elle est **mesurée** au décodeur
  (`MediaMetadataRetriever`) à la lecture des parties, puis retenue par `_id`,
  le contenu d'une partie ne changeant jamais. Sans ce cache, rouvrir un fil de
  vingt vocaux les remesurerait tous à chaque rafraîchissement.
- Ce que l'app ne sait pas montrer, elle le **confie** : un PDF, une vidéo, une
  vCard s'ouvrent d'un appui dans l'application que l'utilisateur a déjà
  choisie pour ce type. La partie ne peut pas être passée telle quelle —
  `content://mms/part` n'est lisible que par l'app SMS par défaut, le provider
  Telephony n'accordant pas de permission d'URI à un tiers — elle est donc
  recopiée dans le cache, d'où le `FileProvider` de l'app la prête le temps
  d'un intent. Quand aucune application ne sait l'ouvrir, la bulle le dit et
  propose de l'**enregistrer** : la pièce jointe n'est pas perdue pour autant,
  et un appui sans effet passerait pour une panne. L'enregistrement passe par
  `ACTION_CREATE_DOCUMENT` plutôt que par un dossier « Téléchargements » écrit
  en direct — aucune permission requise, à n'importe quelle version d'Android,
  et c'est l'utilisateur qui décide où le fichier atterrit.
- La **réception** de MMS n'est pas gérée : `WAP_PUSH_DELIVER` ne porte qu'une
  notification de dépôt à décoder puis à télécharger auprès du MMSC. Ce qui est
  déjà dans `content://mms` s'affiche, en revanche.

## Envoyer un GIF : la taille se choisit, elle ne se rattrape pas

Un GIF est une image, et une image tient dans un MMS — mais c'est la **seule**
pièce jointe dont la taille ne peut pas se corriger après coup. `ImageCompressor`
ré-encode en JPEG : appliqué à un GIF, il n'en garderait qu'une image fixe, ce
qui d'un GIF ne laisse rien. D'où `AttachmentDraft.isCompressible`, qui exclut
`image/gif` alors que c'est bien une image.

Ce qui sauve l'affaire, c'est que le catalogue ne sert pas *un* fichier mais
une **famille** — Klipy en publie quatre tailles (`hd`, `md`, `sm`, `xs`), en
cinq formats chacune — avec le poids de chaque case, **avant** tout
téléchargement. La question « quelle taille envoyer ? » se règle donc à la
sélection, comme celle de la durée d'un vocal, et pour la même raison :
découvrir au retour du MMSC que le message était trop lourd arriverait trop
tard.

- `Gif.bestWithin(budget)` prend **la plus lourde qui tienne** dans le budget de
  l'opérateur — le même `MmsLimits.contentBytes` que pour une photo, lu de la
  configuration et non deviné. Les autres ne descendent jamais du réseau.
- Aucune ne tient ? `AttachmentTooLargeException`, franchement, avant le
  téléchargement. À ce moment-là, l'utilisateur peut encore choisir un autre GIF.
- Le poids annoncé n'engage pas le serveur : le fichier reçu est **re-mesuré**,
  et refusé s'il déborde quand même.
- Ce qui part est **toujours un `image/gif`**. Klipy sert le même dessin en MP4
  pour dix fois moins lourd, mais un MMS qui le porterait ne serait plus un GIF
  chez le destinataire : ce serait une vidéo.
- **Les GIF de Klipy sont lourds** — bien plus que ceux d'un catalogue qui
  optimise pour la vignette. Relevé sur 44 résultats : `hd` pèse 3,6 Mo à la
  médiane, `sm` 448 ko, `xs` 126 ko. Conséquence directe, et c'est le seul
  reproche à lui faire : sur un opérateur qui publie les 300 ko d'AOSP, **un
  GIF sur six n'a aucune déclinaison qui tienne** et se refuse. Dès 600 ko —
  ce que publient la plupart des opérateurs, et 1 Mo sur l'émulateur — ils
  passent tous.

### Deux ports, parce que ce sont deux métiers

`GifCatalog` ne rend que des **adresses** (mis en avant, recherche) : une
grille qui garderait ses GIF en mémoire pèserait plus lourd que le fil qu'elle
recouvre. Il masque aussi la forme de la pagination — Klipy numérote ses pages
(`page`, `has_next`) là où d'autres rendent une position opaque, et
`GifPage.cursor` porte l'un comme l'autre sans que le domaine ait à savoir
lequel. Le fichier n'existe qu'une fois un GIF choisi, et c'est
`MediaDownloader` qui le fait naître — le jumeau exact d'`AttachmentPicker`, à
ceci près qu'il ouvre une adresse au lieu d'un écran du système, et qu'il rend
la même chose : un `AttachmentDraft`.

Le rapatriement est **natif** (`RemoteMedia.kt`), pour la raison qui vaut
partout ailleurs : les octets ne traversent pas le canal. Le fichier doit de
toute façon finir dans `cacheDir/gifs/` derrière le `FileProvider`, puisque
c'est de là que l'envoi du MMS le relira ; le faire remonter en Dart pour le
redescendre aussitôt doublerait le trajet. Le natif n'accepte que **HTTPS**,
plafonne ce qu'il lit (un `Content-Length` menteur ne doit pas pouvoir remplir
le cache) et préfixe le nom d'un identifiant unique — le nom vient du descriptif
du GIF et se répète donc d'un envoi à l'autre.

**La clé d'API arrive par `--dart-define`**, comme celle de Signoz et pour la
même raison. Klipy la veut **dans le chemin** (`/api/v1/<clé>/gifs/...`) et non
dans un en-tête : aucun journal ne porte donc l'URL, seulement le nom du point
d'appel. Sans `KLIPY_API_KEY`, l'app monte `InMemoryGifCatalog` : il ne
montre aucun GIF — il n'en a pas — mais il en a la forme, rapports d'aspect
variés et poids échelonnés autour du budget, ce qu'il faut pour que l'écran
au-dessus reste développable. C'est le parti d'`InMemoryAudioRecorderService`
avec la silhouette d'un son : rien d'inventé qui se ferait passer pour vrai.

```bash
flutter run --dart-define=KLIPY_API_KEY=<clé>
```

### Le panneau, au relevé

Il se pose là où se pose celui de l'enregistrement — **sous** le champ et non
par-dessus : l'ouvrir pousse le fil vers le haut sans jamais masquer ce qu'on
vient d'écrire. Il porte **deux onglets**, `Emoji` et `GIF`, et l'en-tête est
rigoureusement le même de part et d'autre : c'est ce qui fait qu'on passe de
l'un à l'autre sans que rien bouge. Relevé sur l'émulateur (1080 × 2400,
420 dpi ; les dp sont les pixels divisés par 2,625) :

| Élément | Relevé |
|---|---|
| En-tête | **112 dp** : 8 + onglets 40 + 8 + recherche 48 + 8 |
| Onglets | **40 dp**, `SegmentedButton` à deux segments égaux (197,7 dp chacun sur 411) ; actif en `accent`, texte en `onAccent`, l'autre en `surface` |
| Champ de recherche | boîte de 48 dp, pilule de **40 dp** entièrement arrondie, loupe dans un carré de 48 dp calé au bord gauche |
| Grille (GIF) | **deux colonnes** de 193,5 dp, gouttière de 8 dp, coins de 8 dp |
| Panneau | **282 dp** à l'ouverture, dépliable jusqu'à 686 dp sur un écran de 914 (soit ¾) |

- L'**aperçu de la grille** n'est pas un GIF mais le **WebP** de taille
  moyenne : le même dessin y tient en trois fois moins d'octets (153 ko contre
  448 à la médiane), Flutter l'anime aussi bien, et rien ne part de l'aperçu.
- Ce qui se peint **pendant** le téléchargement n'est pas un rectangle uni mais
  l'image floue que Klipy publie avec chaque résultat — quelques centaines
  d'octets déjà encodés en base64. La vignette a tout de suite les bonnes
  couleurs, et l'arrivée du GIF ne fait pas surgir une image là où il n'y avait
  rien.
- **La grille est en quinconce**, pas en damier : chaque vignette garde le
  rapport d'aspect de son GIF (relevés : 508 × 284, 508 × 508, 508 × 231…).
  Une grille à cases égales recadrerait les GIF panoramiques, qui sont la
  moitié du catalogue. Elle est écrite à la main, sans paquet tiers : le
  catalogue publie les dimensions de l'aperçu, il n'y a donc rien à mesurer —
  un GIF va dans la colonne la plus courte, et c'est tout l'algorithme.
- La recherche de GIF part **quand la frappe s'arrête** (300 ms) : sans ce
  délai, « chat » lancerait quatre requêtes dont trois seraient jetées, et la
  grille clignoterait à chaque lettre. Celle des emoji, non — le délai n'existe
  qu'à cause du réseau, et la table est en mémoire : la faire attendre ne
  protégerait rien et rendrait la frappe molle.
- Le témoin de chargement du bas ne s'allume **que pendant** l'arrivée d'une
  page. Lié à « il en reste », il tournerait en permanence pour annoncer une
  attente qui n'a pas commencé.
- Changer d'onglet **vide la recherche** : « chien » ne veut pas dire la même
  chose dans une table d'emoji et dans un catalogue de GIF, et garder le terme
  laisserait croire que le second onglet n'a rien trouvé.
- Les onglets sont le **`SegmentedButton` de Material**, et non deux pilules
  bricolées : c'est bien « choisir l'un des deux » que fait l'app d'origine, et
  le composant apporte ce qu'un couple de boutons n'a pas — le rôle
  d'accessibilité de chaque segment, l'annonce de la sélection (`selected=true`
  au relevé), la navigation au clavier. Trois réglages le ramènent au relevé :
  `expandedInsets` (sans lui, « Emoji » serait plus étroit que « GIF »),
  `showSelectedIcon: false` (la coche de Material pousserait le libellé hors de
  son segment) et `tapTargetSize: shrinkWrap` (sans quoi la rangée de 40 dp
  grandirait de huit points pour atteindre les 48 dp de zone tactile).
- Le texte du champ de recherche est **centré dans sa pilule**, ce qui ne va pas
  de soi : le padding par défaut d'un champ dense le pose contre le haut de sa
  boîte, et il se lisait cinq points trop haut (relevé : 22 px au-dessus contre
  50 en dessous, sur une pilule de 105). Il faut `textAlignVertical: center`
  **et** `contentPadding: EdgeInsets.zero` — le centrage n'a d'effet qu'une fois
  le padding retiré.

### Il se referme par le bouton qui l'a ouvert

Le champ de rédaction porte désormais, au bout du texte, le **bouton emoji** de
l'app d'origine — et c'est un **interrupteur** : dans l'app d'origine, son
libellé d'accessibilité passe de « Afficher » à « Masquer ». C'est le geste le
plus court pour récupérer le clavier, la main étant déjà là ; il se remplit
quand le panneau est ouvert, comme le « + » se remplit quand le plateau porte
quelque chose. Le panneau des sources reste l'autre chemin, et il ouvre
directement l'onglet GIF.

Le glissé referme aussi, en deux temps — replier, puis fermer — comme une
feuille modale. Il se prend sur la **rangée de recherche** et non sur les
onglets : relevé à l'émulateur sur notre propre build, un glissé qui part d'un
onglet finit par le sélectionner au passage, et on se retrouve sur les GIF pour
avoir voulu agrandir les emoji.

### Un écart assumé, et un appui qui ne s'envoie pas

- **L'onglet `Autocollants` n'est pas repris**, seul des trois de l'app
  d'origine : il relève du RCS, que l'app ne fait pas. Le panneau des sources
  applique déjà cette règle — un onglet mort ferait une capture plus
  ressemblante et une app qui promet ce qu'elle ne tient pas.
- **Les puces de tendances (`#mdr`, `#amour`…) ne sont pas reprises** non plus.
  Elles proposent des idées à qui n'en a pas ; le champ de recherche fait la
  même chose sans occuper une rangée en permanence, et la grille commence alors
  au premier pixel du défilement. Le port a perdu sa méthode `categories()`
  avec elles : ce qui ne s'affiche plus n'a pas à continuer d'être lu.
- **Un appui joint, il n'envoie pas.** L'app d'origine ne montre pas d'étape
  intermédiaire — ni aperçu ni confirmation — et celle-ci non plus : le GIF part
  sur le plateau, exactement comme un vocal qu'on vient d'enregistrer, et c'est
  le champ de rédaction qui garde le dernier mot. C'est ce qui laisse ajouter
  une légende, retirer le GIF ou en choisir un autre — et ce qui fait qu'un
  appui de trop ne coûte pas un MMS. Ce que l'émulateur n'a pas pu trancher (il
  refuse toute pièce jointe, faute de MMS configuré), c'est donc une **décision**
  et non un relevé.

## Les emoji : une table générée, et deux rangées de mémoire

L'onglet `Emoji` n'a ni réseau ni clé : la table est une **constante du
domaine**, comme la taille d'un segment SMS. Un port n'aurait rien à adapter —
elle ne varie pas d'un appareil à l'autre, et ne se lit nulle part.

Elle n'est pas écrite à la main non plus. La première version en comptait cinq
cents, choisis à vue, et il en manquait forcément : « les emoji habituels » de
quelqu'un ne sont jamais tout à fait ceux d'un autre. Elle est donc
**générée** — `tool/generate_emoji_table.dart`, relancé à chaque version
d'Unicode — depuis deux sources qui existent précisément pour ça :

| Source | Ce qu'elle donne |
|---|---|
| Unicode `emoji-test.txt` | la liste, l'**ordre** et les familles — celles de tous les claviers |
| CLDR (annotations `fr`) | le **nom français** et les **mots-clés** de chaque emoji |

**1 906 emoji**, contre 502 auparavant. Le fichier produit
(`emoji_table.dart`) est committé : l'app ne télécharge rien.

- Les **mots-clés** sont ce qui sépare une recherche qui trouve d'une recherche
  qui demande de deviner l'intitulé exact. « mdr » ne ressemble à aucun nom
  d'emoji, et pourtant c'est ce qu'on tape — CLDR le range dans les mots-clés
  de 😂, 🤣 et 😹. Une table écrite à la main n'aurait jamais eu ça.
- La recherche **replie les accents** dans les deux sens : « ecoeure » trouve
  « écœuré », « coeur » trouve « cœur ». Sans cela, elle ne sert qu'à ceux qui
  savent déjà comment la table a orthographié ce qu'ils cherchent. Elle replie
  aussi l'apostrophe typographique de CLDR (« il y a quelqu'un ? »), que
  personne ne tape.
- Ce qui **commence** par le terme passe devant : « chat » rend le chat avant
  le chapeau, dont un mot-clé le contient.
- Les formes repliées sont **calculées une fois** : une recherche parcourt deux
  mille emoji et une quinzaine de mots-clés chacun, et replier à chaque frappe
  reviendrait à normaliser trente mille chaînes par lettre tapée. Mesuré :
  22 ms au premier appui, 0,4 ms ensuite.
- Le nom sert aussi de **libellé d'accessibilité** : un lecteur d'écran ne sait
  pas dire un glyphe.

**Deux choses restent écartées de la table**, et ce sont les seules :

- les **teintes de peau** (👍🏽) — 1 875 variantes qui multiplieraient la table
  par six pour la même grille. Les claviers montrent la base et laissent
  l'appui long faire le reste : ce sera une fonctionnalité, pas une ligne de
  table ;
- les **modificateurs seuls** (le groupe « Component » d'Unicode), qui ne
  s'affichent pas isolément.

### Les récents sont le seul état, et ils se persistent

C'est la seule chose qui distingue un clavier utile d'une grille de trois cents
caractères : neuf fois sur dix, l'emoji cherché est celui qu'on a déjà mis.
D'où un port (`EmojiHistoryRepository`) et non une liste en mémoire — l'app
d'origine s'en souvient d'une session à l'autre, et l'oublier reviendrait à
retomber chaque matin sur « Vous n'avez encore utilisé aucun emoji ».

- **Deux rangées de neuf**, au relevé. Au-delà, la section pousserait la grille
  hors de l'écran pour ranger des emoji qu'on n'a mis qu'une fois.
- Réutiliser un emoji le **remonte** au lieu de l'ajouter une seconde fois.
- C'est la **seule section qui se montre vide** : l'app d'origine y écrit
  qu'aucun emoji n'a encore servi, ce qui explique pourquoi la première
  ouverture ne ressemble pas aux suivantes. Une famille vide, elle, n'aurait
  rien à dire — elle est simplement absente.

### La grille et sa barre, au relevé

| Élément | Relevé |
|---|---|
| Grille | **9 colonnes**, cellules de 44,2 × 48 dp, retrait de 6 dp, glyphe de **32 dp** |
| En-tête de famille | 26 dp, capitales, 12 sp, en `textMuted` |
| Barre du bas | **48 dp** ; icônes de 20 dp dans des cases de 48 dp |
| Famille active | disque de **34 dp** en `accentSoft`, glyphe en `accent` |
| Retour arrière | **calé à droite**, dans sa propre case de 48 dp |

- **La grille est virtualisée par rangées.** Trois cents `Text` construits d'un
  coup pour n'en montrer que soixante-dix coûteraient une demi-seconde à chaque
  ouverture. Toutes les hauteurs étant connues d'avance (48 dp par rangée, 26
  par en-tête), la position de chaque famille se **calcule** au lieu de se
  mesurer : c'est ce qui permet à la fois de sauter à une famille d'un appui et
  de savoir laquelle est à l'écran.
- **Le retour arrière n'est pas dans la liste défilante** des familles, il est
  calé dans sa propre case (relevé) : une touche qui efface ne doit pas pouvoir
  se dérober sous le doigt parce qu'on a fait défiler les familles.
- Il efface **un caractère perçu**, pas une unité de code : `👨‍👩‍👧` en compte
  huit, et reculer d'une seule laisserait derrière un morceau de famille et une
  jonction orpheline. C'est le découpage en graphèmes (`String.characters`) qui
  dit ce qu'« un caractère » veut dire.
- L'emoji s'insère **au curseur**, pas au bout : on en ajoute souvent un au
  milieu d'une phrase déjà écrite, et le coller à la fin obligerait à le
  redéplacer à la main.

## Enregistrer un vocal : la limite se pose sur la durée, pas sur le fichier

Une photo trop lourde s'allège ; une phrase, non. La seule façon de faire tenir
un vocal dans un MMS est de le **raccourcir**, et cela ne se décide pas après
coup : découvrir au retour du MMSC que le message était trop long ferait perdre
ce qui vient d'être dit, et une phrase se redit mal.

- Le port `AudioRecorderService` est le jumeau du lecteur : **un seul micro**,
  un état publié que le panneau reconnaît, et des octets qui ne traversent pas
  le canal — ce que rend `stop()` est une URI, comme le sélecteur de pièces
  jointes.
- **AMR-NB, 12,2 kbit/s.** C'est le codec de parole du cœur de la spécification
  MMS — celui qu'un téléphone d'en face lit sans transcodage — et son débit
  *constant* est ce qui permet de dire, **avant** d'enregistrer, combien de
  temps le vocal peut durer. `VoiceRecording.maxDurationIn(limits)` divise le
  budget de l'opérateur par ce débit ; c'est la même limite lue que pour les
  photos, exprimée en secondes. Un AAC de meilleure qualité tiendrait quatre
  fois moins longtemps dans le même budget, sans garantie d'être lu à l'arrivée.
- L'arrêt au budget est confié à `MediaRecorder.setMaxDuration` : compter côté
  Dart pour couper laisserait passer le trajet du message, et un fichier hors
  budget. Le micro se referme donc seul, le port passe en `recorded`, et ce qui
  a été dit reste joignable.
- La **permission micro se demande au geste**, pas à l'accueil avec les SMS :
  qui n'envoie jamais de vocal n'a aucune raison d'accorder son micro à une
  application de SMS. C'est aussi ce que fait l'app d'origine.
- La source est `VOICE_COMMUNICATION` — celle que le système traite (bruit de
  fond, écho, gain), et c'est ce que le panneau annonce sous « Suppression du
  bruit ». Là où l'appareil ne la sert pas, le micro nu prend le relais et le
  panneau **ne promet plus rien** : la pastille disparaît, sa place reste
  réservée pour que la piste ne se déplace pas d'un appareil à l'autre.
- Le niveau du micro est **relevé**, dix fois par seconde, par
  `getMaxAmplitude()` — le pendant exact de la position de lecture. La piste
  est **ancrée à droite** : le relevé le plus récent au bord droit, les
  précédents défilant vers la gauche (relevé à l'émulateur : la piste part du
  bord droit à deux secondes, atteint le bord gauche vers cinq, puis défile).
  Un silence y reste une barre de hauteur minimale — c'est ce minimum, et non
  un dessin de secours, qui donne à un enregistrement muet l'allure pointillée
  de l'app d'origine.
- La durée annoncée est **relue du fichier** (`MediaMetadataRetriever`) et non
  reprise du compteur : c'est ce qui a réellement été écrit qui partira. Elle
  voyage ensuite dans `AttachmentDraft.durationMs` — un vocal qu'on vient
  d'enregistrer n'a pas à être remesuré, contrairement à celui qu'on reçoit.
- Le fichier vit dans `cacheDir/voice/`, prêté par le `FileProvider` comme les
  photos prises et les vCards : c'est sous cette forme que l'envoi du MMS le
  relit. « Annuler » et « Recommencer » l'effacent — une seule règle, dans les
  deux états où le bouton existe ; seul le sort du **panneau** les distingue.
- Le panneau reprend les trois états de l'app d'origine (invitation,
  enregistrement, relecture) et ses trois boutons. **Exception assumée** :
  l'app d'origine ouvre sur une illustration, remplacée ici par le geste à
  faire — une illustration qui n'existe pas dans l'app se dessinerait mal et
  vieillirait seule.

### Un micro, deux gestes, deux surfaces

Le disque au bout du champ porte **deux gestes**, et c'est là tout l'intérêt :
dire trois mots ne demande alors qu'un appui, là où le panneau en demande trois
(ouvrir, enregistrer, joindre). `VoiceRecorderSurface` dit qui montre
l'enregistrement — `panel` ou `hold` — sans que le port en sache rien : pour
lui, il n'y a qu'un micro et qu'un état.

| Geste | Ce qui arrive |
|---|---|
| Appui **bref** | Le panneau s'ouvre sous le champ, micro fermé. |
| Appui **maintenu** | Le micro s'ouvre tout de suite ; la pilule devient la barre `● 00:03 🗑 ‹ Faire glisser pour annuler`, le disque gonfle et rougit, une pastille cadenas paraît au-dessus. |
| **Relâcher** | Le vocal est **joint**, pas envoyé — l'app d'origine laisse ajouter une légende. |
| Glisser vers la **corbeille** | Annulé sous le doigt, sans attendre qu'il se lève : « faire glisser pour annuler » annule quand on a glissé. |
| Glisser vers le **cadenas** | Le doigt s'en va, l'enregistrement continue, et le **panneau prend le relais** — il porte déjà « stop », « Recommencer » et « Joindre ». |

- **La barre remplace la pilule, elle ne s'y ajoute pas** : même hauteur, mêmes
  coins, même fond. Rien ne doit sauter au moment où le micro s'ouvre. Le
  disque, lui, **déborde de sa boîte** au lieu de l'agrandir (152 px contre 132
  au relevé, soit 64 dp contre 56) : une pilule qui changerait de hauteur
  pousserait tout le fil de quatre pixels au moment précis où l'utilisateur ne
  regarde que son doigt. Son glyphe ne grandit pas — sur l'appareil, l'icône
  fait la même largeur dans les deux états.
- **La barre ne se peint qu'une fois le micro ouvert.** Entre l'appui et le
  premier octet, il y a une permission à demander : peindre avant de savoir
  promettrait un enregistrement qui n'a pas commencé, et le compteur resterait
  à zéro sans que rien le dise. D'où l'état intermédiaire `opening` du champ —
  un doigt qui se lève pendant ce temps-là ne doit pas laisser une barre
  derrière lui.
- **Une surface à la fois.** Le panneau déjà ouvert garde la main : `hold()`
  rend `false` plutôt que d'ouvrir un second micro, et le champ ne peint rien.
  Deux surfaces pour un même enregistrement se contrediraient, et le second
  compteur resterait à zéro.
- **La géométrie du glissé ne remonte pas.** Le champ borne le déplacement,
  calcule les deux distances (96 dp vers la corbeille, 72 vers le cadenas, la
  dominante l'emportant en diagonale) et ne publie que la **décision**. Le
  provider ne connaît que trois verbes : `lock`, `close`, `release`.
- Le geste **dit ce qu'il va faire avant de le faire** : la corbeille rougit et
  la barre s'efface à l'approche de l'annulation, le cadenas se ferme à
  l'approche du verrou. Jamais jusqu'à disparaître, cela dit — une barre
  effacée laisserait croire que c'est déjà annulé alors que le doigt peut encore
  revenir.
- Le budget de l'opérateur atteint pendant un maintien **joint** le vocal, comme
  si le doigt s'était levé : laisser une barre à compteur figé sous un doigt qui
  ne commande plus rien serait pire que de conclure à sa place.
- **Ce que les captures ne montrent pas**, et qui est donc une décision et non
  un relevé : à quoi ressemble l'enregistrement une fois verrouillé. Il est ici
  rendu au panneau, qui porte déjà exactement les trois boutons qu'un
  enregistrement sans doigt réclame.
- Le vocal enregistré s'écoute **avec le lecteur des bulles**, pas avec un
  aperçu à part : `AudioPlayerService` accepte indifféremment l'identifiant
  d'une partie du stock et l'URI d'un brouillon (`AudioSource.uriOf` côté
  natif). Un brouillon s'écoute donc exactement comme une bulle, sans rien
  garder sur le disque : il ne doit pas survivre à l'écran qui l'a produit.

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

Les deux services distants s'activent à la compilation, et l'app tourne sans
eux :

```bash
flutter run -d <android_device> \
  --dart-define=KLIPY_API_KEY=<clé> \
  --dart-define=SIGNOZ_INGEST_URL=<url>
```
