import 'package:messages/core/application/dtos/avatar.dto.dart';
import 'package:messages/core/application/dtos/conversation_details.dto.dart';
import 'package:messages/core/application/services/avatar_palette.service.dart';
import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/core/domain/model/address.dart';

/// Assemble l'écran de détails d'un fil : l'en-tête que la liste sait déjà
/// faire, plus le **détail des interlocuteurs** — que la liste, elle, replie en
/// un seul titre (« Alice, Bob ») et une seule pastille.
///
/// C'est toute la différence entre les deux écrans, et la raison de ce service
/// à part : la liste répond à « qui m'a écrit ? », les détails à « qui est
/// dans ce fil, et que sait-on de chacun ? ».
class ConversationDetailsService {
  final ConversationListService _conversations;
  final ContactDirectoryService _directory;

  const ConversationDetailsService({
    required ConversationListService conversations,
    required ContactDirectoryService directory,
  }) : _conversations = conversations,
       _directory = directory;

  /// `null` si le fil n'existe plus — supprimé depuis une autre app pendant
  /// qu'on regardait ses détails.
  Future<ConversationDetailsDto?> byId(String threadId) async {
    final conversation = await _conversations.byId(threadId);
    if (conversation == null) return null;

    final directory = await _directory.load();
    final participants = conversation.addresses
        .map(Address.tryParse)
        .whereType<Address>()
        .map((address) {
          final contact = directory.lookup(address);
          final name = contact?.displayName ?? address.display;
          return ParticipantDto(
            contactId: contact?.id,
            displayName: name,
            // Un numéro sans fiche est déjà son propre nom : le répéter sous
            // lui-même ferait deux lignes identiques.
            addressLabel: name == address.display ? '' : address.display,
            rawAddress: address.raw,
            avatar: AvatarDto(
              initial: contact?.initial ?? _initialOf(address),
              // La graine est le nom du contact quand il y en a un : la même
              // règle que la liste, pour que la pastille ne change pas de
              // couleur d'un écran à l'autre.
              colorSlot: AvatarPaletteService.slotFor(
                contact?.displayName ?? address.key,
              ),
              photo: contact?.photo,
            ),
          );
        })
        .toList();

    return ConversationDetailsDto(
      conversation: conversation,
      participants: participants,
    );
  }

  /// Sans contact, seul un expéditeur nommé (« ORANGE ») donne une initiale ;
  /// un numéro reste une pastille à icône.
  String _initialOf(Address address) {
    if (!address.isAlphanumeric) return '';
    return address.raw.trim().substring(0, 1).toUpperCase();
  }
}
