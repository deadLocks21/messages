import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/contact.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';

/// Fabriques de données de test : des valeurs par défaut plausibles, et le seul
/// champ qui compte au cas de test explicité à l'appel.
abstract final class Build {
  static var _sequence = 0;

  static Address address(String raw) => Address.parse(raw);

  static Contact contact({
    String? id,
    String displayName = 'Camille Rousseau',
    List<String> addresses = const ['+33612345678'],
  }) {
    _sequence++;
    return Contact(
      id: id ?? 'contact-$_sequence',
      displayName: displayName,
      addresses: addresses.map(Address.parse).toList(),
    );
  }

  static Message message({
    String? id,
    String threadId = 'thread-1',
    String address = '+33612345678',
    String body = 'Coucou',
    DateTime? sentAt,
    MessageDirection direction = MessageDirection.incoming,
    MessageStatus? status,
    bool read = true,
  }) {
    _sequence++;
    return Message(
      id: id ?? 'message-$_sequence',
      threadId: threadId,
      address: Address.parse(address),
      body: body,
      sentAt: sentAt ?? DateTime(2026, 8, 25, 10, 0),
      direction: direction,
      status:
          status ??
          (direction == MessageDirection.outgoing
              ? MessageStatus.sent
              : MessageStatus.received),
      read: read,
    );
  }
}
