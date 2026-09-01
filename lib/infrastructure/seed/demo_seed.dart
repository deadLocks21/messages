import 'dart:typed_data';

import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/model/reaction_codec.dart';
import 'package:messages/infrastructure/attachments/sample_image.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';

/// Jeu de données de démonstration, monté quand l'app tourne hors Android
/// (macOS, web) : sans stock Telephony, l'UI n'aurait rien à afficher.
///
/// Les dates sont relatives à `now` pour que la liste garde une allure crédible
/// (« 10:24 », « hier », « lun. ») quel que soit le jour où on lance la démo.
abstract final class DemoSeed {
  static void install({
    required InMemorySmsStore store,
    required InMemoryContactRepository contacts,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    contacts.contacts
      ..clear()
      ..addAll(_contacts());
    for (final message in _messages(store, reference)) {
      store.insert(message);
    }
  }

  static List<Contact> _contacts() => [
    Contact(
      id: 'contact-1',
      displayName: 'Camille Rousseau',
      addresses: [Address.parse('+33612345678')],
    ),
    Contact(
      id: 'contact-2',
      displayName: 'Julien Marchand',
      addresses: [Address.parse('+33623456789')],
    ),
    Contact(
      id: 'contact-3',
      displayName: 'Maman',
      addresses: [Address.parse('+33634567890')],
    ),
    Contact(
      id: 'contact-4',
      displayName: 'Léa Bonnet',
      addresses: [Address.parse('+33645678901')],
    ),
  ];

  static List<Message> _messages(InMemorySmsStore store, DateTime now) {
    final camille = Address.parse('+33612345678');
    final julien = Address.parse('+33623456789');
    final maman = Address.parse('+33634567890');
    final lea = Address.parse('+33645678901');
    final banque = Address.parse('36002');
    final operateur = Address.parse('ORANGE');

    var sequence = 0;
    Message make(
      Address address,
      String body,
      Duration ago, {
      bool outgoing = false,
      bool read = true,
      MessageStatus? status,
      List<Attachment> attachments = const [],
    }) {
      sequence++;
      return Message(
        id: 'demo-$sequence',
        threadId: store.threadIdFor([address]),
        address: address,
        body: body,
        sentAt: now.subtract(ago),
        direction: outgoing ? MessageDirection.outgoing : MessageDirection.incoming,
        status: status ??
            (outgoing ? MessageStatus.delivered : MessageStatus.received),
        read: read,
        attachments: attachments,
      );
    }

    /// Une pièce jointe de démonstration, avec de vrais octets déposés dans le
    /// stock : la vignette de la bulle décode réellement, comme sur téléphone.
    Attachment photo(String id, String fileName, int argb) {
      const width = 640;
      const height = 480;
      final bytes = SampleImage.solid(width: width, height: height, argb: argb);
      store.putAttachmentBytes(id, bytes);
      return Attachment(
        id: id,
        mimeType: 'image/png',
        fileName: fileName,
        byteSize: bytes.length,
        width: width,
        height: height,
      );
    }

    /// Un vocal. Sans octets : la doublure de lecteur n'émet aucun son, elle
    /// avance — ce qu'il lui faut, c'est la durée annoncée.
    Attachment voice(String id, Duration duration) => Attachment(
      id: id,
      mimeType: 'audio/amr',
      fileName: 'vocal.amr',
      byteSize: 24 * 1024,
      durationMs: duration.inMilliseconds,
    );

    Attachment document(String id, String fileName, String content) {
      final bytes = Uint8List.fromList(content.codeUnits);
      store.putAttachmentBytes(id, bytes);
      return Attachment(
        id: id,
        mimeType: 'application/pdf',
        fileName: fileName,
        byteSize: bytes.length,
      );
    }

    return [
      // Un fil actif, avec des non-lus : c'est celui qui ouvre la liste.
      make(camille, 'Tu es dispo ce soir pour le ciné ?', const Duration(hours: 30)),
      make(camille, 'Oui ! Séance de 20h ça te va ?', const Duration(hours: 29, minutes: 55), outgoing: true),
      make(camille, 'Parfait, je prends les places', const Duration(hours: 29, minutes: 50)),
      make(camille, 'C\'est bon, réservé 🎟️', const Duration(minutes: 12), read: false),
      make(camille, 'Rangée F, places 12 et 13', const Duration(minutes: 11), read: false),
      // Un MMS reçu, avec légende : la bulle porte l'image *et* le texte.
      make(
        camille,
        'Les places 🎟️',
        const Duration(minutes: 10),
        read: false,
        attachments: [photo('part-1', 'places.png', 0xFF8A5100)],
      ),
      // Un vocal reçu : la bulle en fait un lecteur, pas une ligne de fichier.
      make(
        camille,
        '',
        const Duration(minutes: 9),
        read: false,
        attachments: [voice('part-4', const Duration(seconds: 4))],
      ),

      // Un fil récent sans non-lu, avec un envoi encore en cours.
      make(julien, 'On se cale un créneau pour la revue ?', const Duration(hours: 3)),
      // Deux réactions, telles qu'elles arrivent réellement : des SMS. Elles
      // n'apparaissent pas comme des bulles — le repli les accroche à celles
      // qu'elles citent. C'est le seul moyen de développer l'affichage hors
      // téléphone, et de voir tout de suite si l'on a cassé le rattachement.
      make(
        julien,
        ReactionCodec.encode(
          emoji: '😂',
          target: 'On se cale un créneau pour la revue ?',
        ),
        const Duration(hours: 2, minutes: 59),
        outgoing: true,
      ),
      make(julien, 'Jeudi 14h chez moi ?', const Duration(hours: 2, minutes: 58), outgoing: true, status: MessageStatus.sent),
      // Le tapback d'un iPhone, dans sa langue et sa forme d'origine : c'est
      // exactement ce que le stock contient quand un correspondant Apple
      // réagit à l'un de nos messages.
      make(julien, 'Liked “Jeudi 14h chez moi ?”', const Duration(hours: 2, minutes: 57)),
      // Une pièce jointe non visuelle : la bulle en fait une ligne de fichier.
      make(
        julien,
        'Le compte rendu',
        const Duration(hours: 2, minutes: 50),
        attachments: [
          document('part-3', 'compte-rendu.pdf', '%PDF-1.4\n% demo\n'),
        ],
      ),

      // Un fil de la veille.
      make(maman, 'Tu passes dimanche ?', const Duration(days: 1, hours: 5)),
      make(maman, 'Oui, vers midi. J\'apporte le dessert', const Duration(days: 1, hours: 4), outgoing: true),
      // Un MMS envoyé sans légende : le fil doit l'annoncer par « Photo ».
      make(
        maman,
        '',
        const Duration(days: 1, hours: 3),
        outgoing: true,
        attachments: [photo('part-2', 'gateau.png', 0xFF5BB874)],
      ),
      // Le même lecteur, sur une bulle envoyée : le bouton s'y peint à
      // l'envers, plein de la couleur du texte.
      make(
        maman,
        '',
        const Duration(days: 1, hours: 2),
        outgoing: true,
        attachments: [voice('part-5', const Duration(seconds: 12))],
      ),

      // Un envoi en échec, pour l'état « Non distribué ».
      make(lea, 'Bon anniversaire !! 🎂', const Duration(days: 2), outgoing: true, status: MessageStatus.failed),

      // Numéro court et expéditeur alphanumérique : les deux cas où il n'y a ni
      // contact ni numéro affichable.
      make(banque, 'Votre code de validation est 481920. Ne le communiquez à personne.', const Duration(days: 3), read: false),
      make(operateur, 'Votre facture de 24,99 € est disponible dans votre espace client.', const Duration(days: 5)),
    ];
  }
}
