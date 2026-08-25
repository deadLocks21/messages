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
