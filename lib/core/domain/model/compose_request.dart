import 'package:messages/core/domain/model/address.dart';

/// Demande d'ouverture d'un fil venue de l'extérieur de l'app : appui sur une
/// notification, lien `sms:` d'un navigateur, partage « Envoyer par SMS » d'une
/// autre application.
///
/// [body] est le texte pré-rempli que certaines de ces sources fournissent
/// (`sms_body`, `Intent.EXTRA_TEXT`). Il n'est jamais envoyé tel quel : il
/// atterrit dans le champ de rédaction, à l'utilisateur de valider.
class ComposeRequest {
  final Address? recipient;
  final String? body;

  const ComposeRequest({this.recipient, this.body});

  /// Une demande sans destinataire ni texte n'a rien à ouvrir.
  bool get isEmpty => recipient == null && (body == null || body!.isEmpty);
}
