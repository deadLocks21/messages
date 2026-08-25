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
  final bool isMuted;
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
    this.isGroup = false,
    this.draft,
  });

  bool get hasUnread => unreadCount > 0;
  bool get hasDraft => draft != null && draft!.trim().isNotEmpty;
}
