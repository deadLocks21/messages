import 'dart:async';

import 'package:flutter/services.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/compose_request.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/core/domain/model/sms_event.dart';

/// Pont bas niveau vers le stock Telephony d'Android.
///
/// Une seule classe traduit les `Map` du canal en modèles Domain ; les
/// repositories `Android*` au-dessus n'ont plus que de l'orchestration. Les
/// erreurs de plateforme sont converties en exceptions du domaine
/// ([SmsException]) pour que la couche application n'ait jamais à connaître
/// `PlatformException`.
///
/// Contrat côté natif : voir `android/app/src/main/kotlin/.../SmsChannel.kt`.
class AndroidSmsChannel {
  static const _methods = MethodChannel('fr.dtfh.messages/sms');
  static const _events = EventChannel('fr.dtfh.messages/sms_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  const AndroidSmsChannel({
    MethodChannel channel = _methods,
    EventChannel eventChannel = _events,
  }) : _channel = channel,
       _eventChannel = eventChannel;

  // ---------------------------------------------------------------- fils

  Future<List<Conversation>> listConversations() async {
    final raw = await _invoke<List<Object?>>('listConversations');
    return (raw ?? const []).map((e) => _conversation(_map(e))).toList();
  }

  Future<Conversation?> getConversation(String threadId) async {
    final raw = await _invoke<Map<Object?, Object?>>('getConversation', {
      'threadId': threadId,
    });
    return raw == null ? null : _conversation(_map(raw));
  }

  Future<String> resolveThreadId(List<Address> recipients) async {
    final raw = await _invoke<String>('resolveThreadId', {
      'recipients': recipients.map((a) => a.raw).toList(),
    });
    if (raw == null || raw.isEmpty) {
      throw const MessageSendFailedException('Fil introuvable');
    }
    return raw;
  }

  Future<void> markThreadRead(String threadId) =>
      _invoke<void>('markThreadRead', {'threadId': threadId});

  Future<void> deleteThread(String threadId) =>
      _invoke<void>('deleteThread', {'threadId': threadId});

  // ------------------------------------------------------------ messages

  Future<List<Message>> listMessages(String threadId, {int limit = 500}) async {
    final raw = await _invoke<List<Object?>>('listMessages', {
      'threadId': threadId,
      'limit': limit,
    });
    return (raw ?? const []).map((e) => _message(_map(e))).toList();
  }

  Future<List<Message>> searchMessages(String query, {int limit = 50}) async {
    final raw = await _invoke<List<Object?>>('searchMessages', {
      'query': query,
      'limit': limit,
    });
    return (raw ?? const []).map((e) => _message(_map(e))).toList();
  }

  Future<Message?> getMessage(String messageId) async {
    final raw = await _invoke<Map<Object?, Object?>>('getMessage', {
      'id': messageId,
    });
    return raw == null ? null : _message(_map(raw));
  }

  Future<Message> sendMessage({
    required List<Address> recipients,
    required String body,
    int? subscriptionId,
  }) async {
    final raw = await _invoke<Map<Object?, Object?>>('sendMessage', {
      'recipients': recipients.map((a) => a.raw).toList(),
      'body': body,
      'subscriptionId': subscriptionId,
    });
    if (raw == null) throw const MessageSendFailedException();
    return _message(_map(raw));
  }

  Future<void> deleteMessage(String messageId) =>
      _invoke<void>('deleteMessage', {'id': messageId});

  // --------------------------------------------------------- permissions

  Future<SmsAccess> checkAccess() async => _access(await _invoke('checkAccess'));

  Future<SmsAccess> requestDefaultSmsApp() async =>
      _access(await _invoke('requestDefaultSmsApp'));

  // ------------------------------------------------- demandes de rédaction

  /// Demande ayant lancé l'app (intent `sms:` / notification). L'appel la
  /// consomme côté natif.
  Future<ComposeRequest?> consumeLaunchRequest() async {
    final raw = await _invoke<Map<Object?, Object?>>('consumeLaunchRequest');
    if (raw == null) return null;
    final request = _composeRequest(_map(raw));
    return request.isEmpty ? null : request;
  }

  /// Demandes arrivées pendant que l'app tourne (`onNewIntent`).
  Stream<ComposeRequest> composeRequests() => _eventChannel
      .receiveBroadcastStream()
      .map((raw) => _map(raw))
      .where((data) => data['type'] == 'compose')
      .map(_composeRequest)
      .where((request) => !request.isEmpty)
      .handleError((_) {});

  // ------------------------------------------------------------ événements

  /// Flux des changements du stock. Une erreur de plateforme est absorbée : une
  /// source muette dégrade le rafraîchissement, elle ne casse pas l'app.
  Stream<SmsEvent> events() => _eventChannel
      .receiveBroadcastStream()
      .map((raw) => _event(_map(raw)))
      .where((event) => event != null)
      .cast<SmsEvent>()
      .handleError((_) {});

  // ------------------------------------------------------------ mapping

  Conversation _conversation(Map<String, Object?> data) {
    final recipients = (data['recipients'] as List<Object?>? ?? const [])
        .map((e) => Address.tryParse(e as String?))
        .whereType<Address>()
        .toList();
    return Conversation(
      id: data['threadId'] as String,
      // Un fil sans destinataire lisible resterait inaffichable : on lui en
      // fabrique un, plutôt que de le faire disparaître de la liste.
      recipients: recipients.isEmpty ? [Address.parse('?')] : recipients,
      snippet: (data['snippet'] as String?) ?? '',
      lastMessageAt: _date(data['date']),
      messageCount: (data['messageCount'] as int?) ?? 0,
      unreadCount: (data['unreadCount'] as int?) ?? 0,
    );
  }

  Message _message(Map<String, Object?> data) {
    return Message(
      id: data['id'] as String,
      threadId: data['threadId'] as String,
      address: Address.tryParse(data['address'] as String?) ?? Address.parse('?'),
      body: (data['body'] as String?) ?? '',
      sentAt: _date(data['date']),
      direction: MessageDirection.fromWire(data['direction'] as String?),
      status: MessageStatus.fromWire(data['status'] as String?),
      read: data['read'] != false,
      subscriptionId: data['subscriptionId'] as int?,
    );
  }

  ComposeRequest _composeRequest(Map<String, Object?> data) => ComposeRequest(
    recipient: Address.tryParse(data['address'] as String?),
    body: data['body'] as String?,
  );

  SmsAccess _access(Object? raw) {
    final data = _map(raw);
    return SmsAccess(
      canReadSms: data['canReadSms'] == true,
      canSendSms: data['canSendSms'] == true,
      canReadContacts: data['canReadContacts'] == true,
      isDefaultSmsApp: data['isDefaultSmsApp'] == true,
    );
  }

  SmsEvent? _event(Map<String, Object?> data) => switch (data['type']) {
    'received' => MessageReceived(_message(_map(data['message']))),
    'status' => MessageStatusChanged(
      messageId: data['id'] as String,
      threadId: (data['threadId'] as String?) ?? '',
      status: MessageStatus.fromWire(data['status'] as String?),
    ),
    'changed' => const StoreChanged(),
    // 'compose' est consommé par `composeRequests()` : ce n'est pas un
    // changement du stock.
    _ => null,
  };

  Map<String, Object?> _map(Object? raw) =>
      (raw as Map<Object?, Object?>? ?? const {}).map(
        (key, value) => MapEntry(key as String, value),
      );

  DateTime _date(Object? millis) => DateTime.fromMillisecondsSinceEpoch(
    millis is int ? millis : 0,
  );

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'not_default_sms_app' => const NotDefaultSmsAppException(),
        'permission_denied' => const SmsPermissionDeniedException(),
        'not_found' => const MessageNotFoundException(),
        _ => MessageSendFailedException(e.message),
      };
    } on MissingPluginException {
      // Le canal n'existe que sur Android : ailleurs, l'assemblage des
      // providers choisit déjà les doublures InMemory. Un appel qui arrive
      // quand même ici est un bug de câblage, pas une erreur utilisateur.
      throw const SmsPermissionDeniedException();
    }
  }
}
