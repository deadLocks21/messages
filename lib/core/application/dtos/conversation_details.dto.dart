import 'package:messages/core/application/dtos/avatar.dto.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';

/// Un interlocuteur du fil, tel que le montre l'écran de détails.
class ParticipantDto {
  /// Identifiant de la fiche du carnet, `null` si le numéro n'y est pas.
  /// C'est lui qui décide du bouton : « Infos contact » ou « Ajouter un
  /// contact ».
  final String? contactId;

  /// Nom du carnet, ou numéro formaté quand il n'y a pas de fiche.
  final String displayName;

  /// Numéro formaté. Vide quand il fait déjà office de [displayName] : la
  /// fiche d'origine n'écrit pas deux fois la même ligne.
  final String addressLabel;

  /// Adresse brute — celle qu'on passe au composeur d'appel ou au carnet.
  final String rawAddress;

  final AvatarDto avatar;

  const ParticipantDto({
    required this.contactId,
    required this.displayName,
    required this.addressLabel,
    required this.rawAddress,
    required this.avatar,
  });

  bool get isKnown => contactId != null;
}

/// Ce que montre l'écran ouvert par un appui sur le nom, en haut d'un fil :
/// l'interlocuteur, ce qu'on peut faire de lui, et les réglages du fil.
class ConversationDetailsDto {
  final ConversationDto conversation;

  /// Les destinataires du fil, dans l'ordre du stock.
  final List<ParticipantDto> participants;

  const ConversationDetailsDto({
    required this.conversation,
    required this.participants,
  });

  /// L'unique interlocuteur d'un fil à deux — `null` pour un groupe, ou pour
  /// un fil dont le stock ne rend aucune adresse lisible.
  ///
  /// Les boutons du haut (appeler, ouvrir la fiche) n'ont de sens que là :
  /// à plusieurs, il n'y a pas *un* numéro à appeler.
  ParticipantDto? get soleParticipant =>
      participants.length == 1 ? participants.first : null;
}
