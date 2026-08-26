import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/conversation.dart';

/// Port de lecture/écriture des **fils** du stock Telephony
/// (`content://mms-sms/conversations`).
///
/// Implémentations : `AndroidConversationRepository` (provider système) et
/// `InMemoryConversationRepository` (dev hors-Android + tests).
abstract interface class ConversationRepository {
  /// Tous les fils, du plus récent au plus ancien.
  Future<List<Conversation>> listAll();

  Future<Conversation?> getById(String threadId);

  /// `thread_id` du fil réunissant exactement ces destinataires, créé au besoin
  /// (`Telephony.Threads.getOrCreateThreadId`). C'est ce qui permet d'ouvrir un
  /// fil avant d'avoir envoyé le premier message.
  Future<String> resolveThreadId(List<Address> recipients);

  /// Marque tous les entrants du fil comme lus.
  /// Marque lus les entrants du fil.
  ///
  /// Rend `true` si le stock a réellement changé. Rouvrir un fil déjà lu est
  /// le cas courant, et il ne doit rien coûter : sans cette réponse, l'app
  /// reconstruisait toute la liste des fils à chaque ouverture.
  Future<bool> markRead(String threadId);

  /// Supprime le fil et tous ses messages.
  Future<void> delete(String threadId);
}
