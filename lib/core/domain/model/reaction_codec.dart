import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/message.dart';

/// Ce qu'un corps de SMS dit quand il transporte une réaction.
class ReactionText {
  /// Emoji d'affichage, résolu par la table de [ReactionCodec].
  final String emoji;

  /// Le texte cité : le début du message visé, tel qu'il a été recopié par
  /// l'expéditeur — ou le libellé d'une pièce jointe (« an image »).
  final String quoted;

  /// La citation était encadrée par des guillemets. Sans eux (« Liked an
  /// image », « 👍 to demain »), le rattachement doit être plus exigeant : la
  /// phrase entière doit correspondre, faute de quoi n'importe quel message
  /// commençant par les bons mots serait avalé.
  final bool wasQuoted;

  /// Une réaction retirée (`Removed a heart from …`) plutôt que posée.
  final bool isRemoval;

  const ReactionText({
    required this.emoji,
    required this.quoted,
    required this.wasQuoted,
    this.isRemoval = false,
  });
}

/// Le format des réactions sur SMS, dans les deux sens.
///
/// ## Pourquoi du texte
///
/// Les réactions de Google Messages sont une fonctionnalité **RCS**, et Android
/// n'expose aucune API RCS aux applications tierces. Le seul canal qui reste
/// est donc le corps du SMS lui-même : on envoie une phrase, calquée sur celles
/// qu'un iPhone envoie quand il « tapback » un correspondant Android, et
/// Google Messages — qui sait les décoder depuis 2022, réglage « Afficher les
/// réactions iPhone en tant qu'emoji », activé par défaut — la repose sur la
/// bulle visée.
///
/// Ce codec vit dans le domaine et non derrière un port, pour la même raison
/// qu'`EmojiCatalog` : il ne dépend d'aucune plateforme, ne varie pas d'un
/// appareil à l'autre et ne se lit nulle part.
///
/// ## Ce qu'on émet, et pourquoi ce n'est pas le format de Google Messages
///
/// Google Messages envoie, lui, `👍 to Bonjour`. On préfère **imiter l'iPhone**
/// (`Liked “Bonjour”`) : c'est ce format-là dont on sait qu'il est décodé à
/// l'arrivée, puisque c'est celui pour lequel la fonctionnalité a été écrite.
/// Les cinq emoji qui ont un tapback équivalent partent donc sous leur verbe
/// anglais ; les autres sous la forme d'iOS 18 (`Reacted 😢 to “…”`), moins
/// sûre mais sans concurrent.
///
/// ## Ce qu'on décode
///
/// Tout ce qu'on a pu identifier : les six verbes d'iOS, leurs traductions
/// françaises, la forme emoji d'iOS 18, celle de Google Messages, et les
/// retraits. Un motif qu'on ne reconnaît pas n'est jamais une perte : le
/// message reste affiché comme le texte qu'il est.
abstract final class ReactionCodec {
  /// Les sept réactions proposées par le sélecteur, dans l'ordre de Google
  /// Messages.
  static const palette = ['👍', '😍', '😂', '😮', '😢', '😡', '👎'];

  /// Emoji → verbe iOS. Les seuls que l'on sache décodés à coup sûr.
  static const _verbs = <String, String>{
    '👍': 'Liked',
    '😍': 'Loved',
    '😂': 'Laughed at',
    '😮': 'Emphasized',
    '👎': 'Disliked',
    '🤔': 'Questioned',
  };

  /// Verbe → emoji. On reprend **la table de Google Messages** plutôt que celle
  /// d'Apple : un `Loved` s'y affiche 😍 et non ❤️, un `Emphasized` 😮 et un
  /// `Questioned` 🤔. Le correspondant qui a réagi sur son iPhone et nous
  /// verrons ainsi le même dessin.
  static const _byVerb = <String, String>{
    'liked': '👍',
    'loved': '😍',
    'laughed at': '😂',
    'emphasized': '😮',
    'disliked': '👎',
    'questioned': '🤔',
    // iOS traduit ses tapbacks dans la langue de l'expéditeur : un iPhone
    // français n'envoie pas « Liked ». Ces formes-là sont relevées sur des
    // messages reçus et restent à confirmer appareil en main — un motif
    // manquant laisse simplement le texte brut à l'écran.
    'a aimé': '👍',
    'aimé': '👍',
    'a adoré': '😍',
    'adoré': '😍',
    'a ri de': '😂',
    'ri de': '😂',
    'a mis en avant': '😮',
    'a souligné': '😮',
    'n\'a pas aimé': '👎',
    'pas aimé': '👎',
    's\'est interrogé sur': '🤔',
    'a questionné': '🤔',
  };

  /// Emoji → ce qu'iOS dit qu'on retire.
  static const _removals = <String, String>{
    '👍': 'a like',
    '😍': 'a heart',
    '😂': 'a laugh',
    '😮': 'an exclamation',
    '👎': 'a dislike',
    '🤔': 'a question mark',
  };

  /// Ce qu'iOS cite d'un message qui n'a pas de texte, et sa traduction.
  static const _attachmentLabels = <AttachmentKind, String>{
    AttachmentKind.image: 'an image',
    AttachmentKind.video: 'a movie',
    AttachmentKind.audio: 'an audio message',
    AttachmentKind.vcard: 'an attachment',
    AttachmentKind.file: 'an attachment',
  };

  /// Les libellés de pièce jointe qu'on sait reconnaître à l'arrivée, dans les
  /// deux langues.
  static const _knownAttachmentLabels = <String>{
    'an image',
    'a movie',
    'an audio message',
    'an attachment',
    'une image',
    'votre image',
    'une vidéo',
    'votre vidéo',
    'un message audio',
    'une pièce jointe',
    'votre pièce jointe',
  };

  /// Longueur au-delà de laquelle la citation est coupée.
  ///
  /// Elle est **large à dessein**. Un emoji fait basculer le SMS en UCS-2,
  /// donc 67 caractères par segment concaténé : citer largement coûte deux ou
  /// trois SMS facturés. C'est le prix d'un rattachement qui aboutit — une
  /// citation trop courte ne retrouve rien à l'autre bout, et la réaction
  /// s'affiche alors en toutes lettres chez le destinataire.
  static const maxQuotedLength = 120;

  /// Le texte à citer pour viser [message].
  ///
  /// Un message sans texte n'a que sa pièce jointe à nommer, comme le fait
  /// iOS — c'est un rattachement plus fragile, mais c'est cela ou renoncer à
  /// réagir aux photos.
  static String targetOf(Message message) {
    if (message.body.trim().isNotEmpty) return message.body.trim();
    final kind = message.attachments.firstOrNull?.kind;
    return _attachmentLabels[kind] ?? 'an attachment';
  }

  /// Cet emoji a-t-il un tapback iOS, et part-il donc sous la forme dont on
  /// sait qu'elle est décodée à l'arrivée ?
  static bool hasTapback(String emoji) => _verbs.containsKey(canonical(emoji));

  /// Le corps du SMS qui porte la réaction [emoji] sur le message cité.
  static String encode({required String emoji, required String target}) {
    final citation = _cite(target);
    final verb = _verbs[canonical(emoji)];
    return verb != null ? '$verb $citation' : 'Reacted $emoji to $citation';
  }

  /// Le corps du SMS qui retire la réaction [emoji].
  static String encodeRemoval({
    required String emoji,
    required String target,
  }) {
    final what = _removals[canonical(emoji)] ?? 'a reaction';
    return 'Removed $what from ${_cite(target)}';
  }

  /// Ce que dit ce corps de message, ou `null` s'il ne dit rien d'une réaction.
  ///
  /// Rendre un [ReactionText] ne suffit pas à replier le message : il faut
  /// encore que la citation retrouve sa cible dans le fil. C'est le garde-fou
  /// qui empêche un « 👍 to be honest » d'avaler une bulle.
  static ReactionText? decode(String body) {
    final text = stripInvisible(body).trim();
    if (text.isEmpty) return null;
    return _decodeRemoval(text) ??
        _decodeVerb(text) ??
        _decodeReacted(text) ??
        _decodeBareEmoji(text);
  }

  /// Ce qu'on montre d'une réaction là où il n'y a de place que pour une ligne
  /// — résumé d'un fil dans la liste, résultat de recherche.
  ///
  /// Le repli n'y est pas disponible : la liste des conversations ne connaît
  /// que le `snippet` que le provider a calculé, pas le fil qui le précède.
  /// On ne peut donc pas dire *à quoi* la réaction répond avec certitude —
  /// seulement montrer ce qu'elle est, plutôt que la phrase anglaise que le
  /// stock contient.
  static String? summarize(String body) {
    final decoded = decode(body);
    if (decoded == null) return null;
    if (decoded.isRemoval) return 'Réaction retirée';
    if (isAttachmentLabel(decoded.quoted)) {
      return '${decoded.emoji} Réaction à une pièce jointe';
    }
    return '${decoded.emoji} Réaction à « ${decoded.quoted} »';
  }

  /// Deux textes désignent-ils le même message ?
  ///
  /// La citation est le **début** du message visé : iOS coupe les longs
  /// messages, et nous aussi. La comparaison ignore donc la fin, la casse, les
  /// espaces multiples et la forme des guillemets — tout ce qu'un aller-retour
  /// par un clavier, un opérateur ou une autre application peut changer sans
  /// changer le message.
  static bool matches(String quoted, String body, {required bool asPrefix}) {
    final needle = normalize(quoted);
    final haystack = normalize(body);
    if (needle.isEmpty) return false;
    return asPrefix ? haystack.startsWith(needle) : haystack == needle;
  }

  /// Le libellé d'une pièce jointe, que la citation ne peut pas comparer au
  /// corps d'un message — il faut alors chercher la dernière pièce jointe du
  /// fil.
  static bool isAttachmentLabel(String quoted) =>
      _knownAttachmentLabels.contains(normalize(quoted));

  /// Forme comparable d'un texte : minuscules, espaces réduits, guillemets et
  /// apostrophes ramenés à une seule forme, points de suspension retirés.
  static String normalize(String text) {
    var value = stripInvisible(text).toLowerCase().trim();
    value = value.replaceAll(RegExp(r'[“”„«»]'), '"');
    value = value.replaceAll(RegExp(r'[’‘]'), "'");
    value = value.replaceAll(RegExp(r'[…]+$'), '');
    value = value.replaceAll(RegExp(r'\.{3,}$'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    return value.trim();
  }

  /// Un emoji sans son sélecteur de présentation ni les invisibles qui
  /// l'entourent : `❤️` et `❤` sont le même dessin, et il ne faut pas deux
  /// entrées de table pour cela.
  static String canonical(String emoji) =>
      stripInvisible(emoji).replaceAll('️', '').replaceAll('︎', '');

  /// Les caractères **invisibles** qu'une application glisse dans son texte.
  ///
  /// Google Messages encadre l'emoji de ses réactions d'espaces de largeur
  /// nulle (`U+200B`) et sépare la citation de ses guillemets par des espaces
  /// fins (`U+200A`) : rien de tout cela ne se voit, et le `U+200B` suffisait à
  /// faire échouer la reconnaissance — un emoji encadré de deux caractères qui
  /// n'en sont pas n'est plus un emoji.
  ///
  /// La **jonction** `U+200D` n'est pas de la partie : elle est structurante,
  /// c'est elle qui tient `👨‍👩‍👧` d'un seul tenant. Pas plus que `U+200C`, qui
  /// sépare des lettres dans les écritures qui en ont besoin — la citation
  /// qu'on recopie n'est pas toujours du français.
  static const _invisible = {
    0x200B, // espace de largeur nulle
    0x2060, // liant sans chasse
    0xFEFF, // marque d'ordre des octets
    0x200E, 0x200F, 0x061C, // marques directionnelles
    0x00AD, // trait d'union conditionnel
    0x180E, // séparateur de voyelle mongol
  };

  static String stripInvisible(String text) => String.fromCharCodes(
    text.runes.where((rune) => !_invisible.contains(rune)),
  );

  /// Nom lisible d'une réaction, pour un lecteur d'écran ou une notification.
  static String describe(String emoji) => switch (canonical(emoji)) {
    '👍' => 'pouce levé',
    '👎' => 'pouce baissé',
    '😍' => 'cœur',
    '😂' => 'rire',
    '😮' => 'surprise',
    '😢' => 'tristesse',
    '😡' => 'colère',
    '🤔' => 'interrogation',
    _ => 'réaction',
  };

  // ------------------------------------------------------------- décodage

  static final _verbPattern = RegExp(
    '^(${_byVerb.keys.map(RegExp.escape).join('|')})\\s+(.+)\$',
    caseSensitive: false,
    dotAll: true,
  );

  static final _reactedPattern = RegExp(
    r'^(?:reacted|a réagi(?: avec)?)\s+(\S+)\s+(?:to|à|au)\s+(.+)$',
    caseSensitive: false,
    dotAll: true,
  );

  static final _bareEmojiPattern = RegExp(
    r'^(\S+)\s+(?:to|à)\s+(.+)$',
    caseSensitive: false,
    dotAll: true,
  );

  static final _removalPattern = RegExp(
    r'^(?:removed|a retiré|a enlevé)\s+(.+?)\s+(?:from|de|à)\s+(.+)$',
    caseSensitive: false,
    dotAll: true,
  );

  /// « Liked “Bonjour” », « A aimé « Bonjour » », « Liked an image ».
  static ReactionText? _decodeVerb(String text) {
    final match = _verbPattern.firstMatch(text);
    if (match == null) return null;
    final emoji = _byVerb[normalize(match.group(1)!)];
    if (emoji == null) return null;
    return _quoted(emoji, match.group(2)!);
  }

  /// « Reacted 😂 to “Bonjour” » — la forme d'iOS 18, pour les emoji qui n'ont
  /// pas de tapback.
  static ReactionText? _decodeReacted(String text) {
    final match = _reactedPattern.firstMatch(text);
    if (match == null) return null;
    final emoji = match.group(1)!;
    if (!_looksLikeEmoji(emoji)) return null;
    return _quoted(emoji, match.group(2)!);
  }

  /// « 😂 to Bonjour » — ce que Google Messages envoie, souvent sans
  /// guillemets.
  static ReactionText? _decodeBareEmoji(String text) {
    final match = _bareEmojiPattern.firstMatch(text);
    if (match == null) return null;
    final emoji = match.group(1)!;
    if (!_looksLikeEmoji(emoji)) return null;
    return _quoted(emoji, match.group(2)!);
  }

  /// « Removed a heart from “Bonjour” ».
  static ReactionText? _decodeRemoval(String text) {
    final match = _removalPattern.firstMatch(text);
    if (match == null) return null;
    final what = normalize(match.group(1)!);
    final emoji = _removals.entries
        .where((e) => e.value == what || what.endsWith(e.value))
        .map((e) => e.key)
        .firstOrNull;
    // « Removed a reaction from … » ne dit pas laquelle : on retire alors la
    // réaction de cet auteur, quelle qu'elle soit.
    if (emoji == null && !what.contains('reaction') && !what.contains('réaction')) {
      return null;
    }
    final quoted = _quoted(emoji ?? '❔', match.group(2)!);
    if (quoted == null) return null;
    return ReactionText(
      emoji: quoted.emoji,
      quoted: quoted.quoted,
      wasQuoted: quoted.wasQuoted,
      isRemoval: true,
    );
  }

  /// Détache la citation de ses guillemets, s'il y en a.
  static ReactionText? _quoted(String rawEmoji, String rest) {
    final trimmed = rest.trim();
    if (trimmed.isEmpty) return null;
    // L'emoji rendu est celui de la table, pas celui du réseau : sans quoi la
    // pastille porterait les invisibles de l'expéditeur.
    final emoji = canonical(rawEmoji);
    final unquoted = _unquote(trimmed);
    if (unquoted != null) {
      return ReactionText(emoji: emoji, quoted: unquoted, wasQuoted: true);
    }
    return ReactionText(emoji: emoji, quoted: trimmed, wasQuoted: false);
  }

  static const _quotePairs = <String, String>{
    '“': '”',
    '"': '"',
    '«': '»',
    '„': '”',
    '‘': '’',
  };

  static String? _unquote(String text) {
    for (final pair in _quotePairs.entries) {
      if (!text.startsWith(pair.key)) continue;
      if (text.length > pair.key.length + pair.value.length &&
          text.endsWith(pair.value)) {
        return text
            .substring(pair.key.length, text.length - pair.value.length)
            .trim();
      }
      // Guillemet ouvrant sans fermant : c'est ce que rend le `snippet` du
      // provider, qui coupe les longs résumés. La citation est amputée, mais
      // son début suffit à retrouver la cible — c'est un préfixe, et c'est
      // ainsi qu'on la compare de toute façon.
      if (text.length > pair.key.length) {
        return text.substring(pair.key.length).trim();
      }
    }
    return null;
  }

  /// La citation, coupée à [maxQuotedLength] sur une frontière de caractère
  /// perçu — couper au milieu d'une séquence emoji donnerait un carré vide.
  ///
  /// Les guillemets sont ceux d'iOS : courbes, et non les droits du clavier.
  static String _cite(String target) {
    final text = target.trim().replaceAll(RegExp(r'\s+'), ' ');
    final runes = text.runes.toList();
    if (runes.length <= maxQuotedLength) return '“$text”';

    // Reculer tant que la coupe tomberait *dans* un caractère perçu : un
    // pouce levé amputé de sa teinte de peau s'affiche en carré vide.
    var end = maxQuotedLength;
    while (end > 0 && (_joins(runes[end]) || runes[end - 1] == 0x200D)) {
      end--;
    }
    return '“${String.fromCharCodes(runes.take(end))}…”';
  }

  /// Une rune qui n'existe qu'attachée à la précédente.
  static bool _joins(int rune) =>
      rune == 0x200D ||
      rune == 0xFE0F ||
      rune == 0xFE0E ||
      rune == 0x20E3 ||
      (rune >= 0x1F3FB && rune <= 0x1F3FF);

  /// Ce jeton est-il un emoji, et rien d'autre ?
  ///
  /// Le motif « 👍 to … » est trop ouvert pour être cru sur parole : sans ce
  /// filtre, « Merci to be fair » deviendrait une réaction.
  static bool _looksLikeEmoji(String token) {
    final runes = canonical(token).runes.toList();
    if (runes.isEmpty || runes.length > 6) return false;
    var pictographic = false;
    for (final rune in runes) {
      if (rune == 0x200D || rune == 0x20E3) continue;
      if (rune >= 0x1F3FB && rune <= 0x1F3FF) continue;
      if (_isPictographic(rune)) {
        pictographic = true;
        continue;
      }
      return false;
    }
    return pictographic;
  }

  static bool _isPictographic(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2B00 && rune <= 0x2BFF) ||
      (rune >= 0x2190 && rune <= 0x21FF) ||
      rune == 0x203C ||
      rune == 0x2049 ||
      rune == 0x2139 ||
      (rune >= 0x2300 && rune <= 0x23FF);
}
