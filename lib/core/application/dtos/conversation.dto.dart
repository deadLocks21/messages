import 'package:messages/core/application/dtos/avatar.dto.dart';

/// Une ligne de la liste des conversations : tout est déjà résolu (nom du
/// contact, brouillon, épinglage) pour que l'UI n'ait plus qu'à peindre.
class ConversationDto {
  final String threadId;

  /// Nom du contact, ou numéro formaté, ou « Alice, Bob » pour un groupe.
  final String title;

  /// Dernier message. Préfixé côté UI par « Brouillon » quand [draft] existe.
  final String snippet;

  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  /// Sourdine sans échéance.
  final bool isMuted;

  /// L'un des destinataires est dans la liste bloquée du système.
  final bool isBlocked;

  /// Fin de la mise en veille, `null` s'il n'y en a pas.
  final DateTime? snoozedUntil;

  /// Graine du thème de discussion, `null` quand le fil suit l'appareil.
  final int? themeSeed;

  /// Fond d'écran du fil, dans le stockage de l'app.
  final String? wallpaperPath;

  /// Ce fil notifie-t-il ? Calculé à la construction du DTO, pas à la lecture :
  /// une veille échue ne doit pas dépendre du moment où l'UI y jette un œil.
  final bool isSilenced;
  final bool isGroup;

  /// Texte tapé mais pas envoyé, s'il y en a un.
  final String? draft;

  /// Adresses brutes du fil — l'UI en a besoin pour « Appeler » ou pour
  /// pré-remplir un nouveau message.
  final List<String> addresses;

  final AvatarDto avatar;

  const ConversationDto({
    required this.threadId,
    required this.title,
    required this.snippet,
    required this.lastMessageAt,
    required this.addresses,
    required this.avatar,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.isMuted = false,
    this.isBlocked = false,
    this.snoozedUntil,
    this.themeSeed,
    this.wallpaperPath,
    this.isSilenced = false,
    this.isGroup = false,
    this.draft,
  });

  bool get hasUnread => unreadCount > 0;
  bool get hasDraft => draft != null && draft!.trim().isNotEmpty;

  /// Le seul champ qu'on remplace après coup : l'aperçu d'un fil sans message
  /// est bâti depuis ses destinataires, et n'apprend son identifiant qu'après.
  ConversationDto copyWith({String? threadId}) => ConversationDto(
    threadId: threadId ?? this.threadId,
    title: title,
    snippet: snippet,
    lastMessageAt: lastMessageAt,
    addresses: addresses,
    avatar: avatar,
    unreadCount: unreadCount,
    isPinned: isPinned,
    isArchived: isArchived,
    isMuted: isMuted,
    isBlocked: isBlocked,
    snoozedUntil: snoozedUntil,
    themeSeed: themeSeed,
    wallpaperPath: wallpaperPath,
    isSilenced: isSilenced,
    isGroup: isGroup,
    draft: draft,
  );
}
