import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/message.dart';

/// Port de lecture/écriture des **messages** (`content://sms`).
///
/// L'envoi est confié à la plateforme (`SmsManager`) : le repository rend
/// immédiatement le message en `sending`, et la suite du cycle de vie arrive
/// par [SmsEventSource] plutôt que par le retour de [send].
abstract interface class MessageRepository {
  /// Messages d'un fil, du plus ancien au plus récent.
  Future<List<Message>> listForThread(String threadId, {int limit});

  /// Recherche plein texte dans le corps des messages (`body LIKE ?`).
  Future<List<Message>> search(String query, {int limit});

  Future<Message?> getById(String messageId);

  /// Dépose le message et l'insère dans le stock. Découpe en plusieurs parties
  /// si le texte dépasse la taille d'un SMS — c'est la plateforme qui s'en
  /// charge.
  ///
  /// [attachments] non vide bascule l'envoi en **MMS** : le transport change
  /// (PDU vers le MMSC au lieu du SMSC), et le message est écrit dans
  /// `content://mms` plutôt que `content://sms`. L'appelant n'a pas à choisir —
  /// c'est la présence de pièces jointes qui décide.
  Future<Message> send({
    required List<Address> recipients,
    required String body,
    List<AttachmentDraft> attachments = const [],
    int? subscriptionId,
  });

  /// Réémet un message en échec, à l'identique.
  Future<Message> resend(String messageId);

  Future<void> delete(String messageId);
}
