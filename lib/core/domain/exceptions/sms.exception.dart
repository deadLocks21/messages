import 'package:messages/core/domain/model/attachment.dart';

/// Erreurs métier du stock SMS. Toutes portent un message affichable tel quel :
/// c'est la couche application qui décide de l'exposer ou de la traduire.
sealed class SmsException implements Exception {
  final String message;
  const SmsException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// L'app n'est pas application SMS par défaut : toute écriture est refusée par
/// Android.
class NotDefaultSmsAppException extends SmsException {
  const NotDefaultSmsAppException()
    : super('Messages doit être votre application SMS par défaut pour envoyer.');
}

/// Permission runtime manquante (lecture ou envoi).
class SmsPermissionDeniedException extends SmsException {
  const SmsPermissionDeniedException()
    : super('L\'accès aux SMS a été refusé.');
}

/// Le dépôt du message a échoué (pas de réseau, SIM absente, numéro refusé).
class MessageSendFailedException extends SmsException {
  final String? reason;
  const MessageSendFailedException([this.reason])
    : super('Le message n\'a pas pu être envoyé.');
}

/// Message ou fil disparu entre la lecture et l'action.
class MessageNotFoundException extends SmsException {
  const MessageNotFoundException() : super('Ce message n\'existe plus.');
}

/// Le MMS dépasse ce que l'opérateur accepte de porter.
///
/// Le message annonce la limite **réellement lue** plutôt qu'un chiffre
/// générique : « trop lourd » sans dire de combien ne dit pas quoi faire.
class AttachmentTooLargeException extends SmsException {
  final MmsLimits limits;

  AttachmentTooLargeException(this.limits)
    : super(
        'Pièces jointes trop lourdes : votre opérateur limite les MMS à '
        '${(limits.maxTotalBytes / 1024).round()} Ko.',
      );
}

/// Trop de pièces jointes pour un seul message ([MmsLimits.maxCount]).
class TooManyAttachmentsException extends SmsException {
  const TooManyAttachmentsException()
    : super('Trop de pièces jointes pour un seul message.');
}

/// Le fichier choisi n'est plus lisible : URI révoquée, fichier supprimé, ou
/// permission de lecture perdue au retour du sélecteur.
class AttachmentUnavailableException extends SmsException {
  const AttachmentUnavailableException()
    : super('Cette pièce jointe n\'est plus accessible.');
}
