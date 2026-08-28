import 'dart:async';

import 'package:flutter/services.dart';
import 'package:messages/core/application/services/logger_application.service.dart';
import 'package:messages/core/domain/exceptions/sms.exception.dart';
import 'package:messages/core/domain/model/address.dart';
import 'package:messages/core/domain/model/attachment.dart';
import 'package:messages/core/domain/model/compose_request.dart';
import 'package:messages/core/domain/model/conversation.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/core/domain/model/message.dart';
import 'package:messages/core/domain/model/sms_access.dart';
import 'package:messages/core/domain/model/sms_event.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';

/// Pont bas niveau vers le stock Telephony d'Android.
///
/// Une seule classe traduit les `Map` du canal en modèles Domain ; les
/// repositories `Android*` au-dessus n'ont plus que de l'orchestration. Les
/// erreurs de plateforme sont converties en exceptions du domaine
/// ([SmsException]) pour que la couche application n'ait jamais à connaître
/// `PlatformException`.
///
/// Contrat côté natif : voir `android/app/src/main/kotlin/.../SmsChannel.kt`.
///
/// ## C'est ici qu'on voit le natif échouer
///
/// La frontière Dart/Kotlin est l'endroit où l'app cesse de savoir ce qui se
/// passe : au-delà, un refus du `ContentProvider`, un MMSC injoignable ou une
/// permission reprise en douce ne remontent que sous forme de
/// `PlatformException`. [_invoke] les journalise **toutes**, avec le nom de la
/// méthode appelée, avant de les traduire en exception du domaine — c'est le
/// seul point de passage obligé, et donc le seul filet qui ne se troue pas
/// quand un appelant oublie d'attraper.
class AndroidSmsChannel {
  static const _methods = MethodChannel('fr.dtfh.messages/sms');
  static const _events = EventChannel('fr.dtfh.messages/sms_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  /// Optionnel : les tests de traduction du canal n'ont rien à journaliser, et
  /// se construisent sans. En production le provider en fournit toujours un.
  final LoggerApplicationService? _logger;

  const AndroidSmsChannel({
    MethodChannel channel = _methods,
    EventChannel eventChannel = _events,
    LoggerApplicationService? logger,
  }) : _channel = channel,
       _eventChannel = eventChannel,
       _logger = logger;

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

  /// Rend `true` si des messages ont réellement basculé en « lu ».
  Future<bool> markThreadRead(String threadId) async =>
      await _invoke<bool>('markThreadRead', {'threadId': threadId}) ?? false;

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

  /// Dépose un message. Avec [attachments], le natif bascule sur le transport
  /// MMS (PDU vers le MMSC) et écrit dans `content://mms` — c'est lui qui
  /// tranche, à partir de ce que porte l'appel.
  Future<Message> sendMessage({
    required List<Address> recipients,
    required String body,
    List<AttachmentDraft> attachments = const [],
    int? subscriptionId,
  }) async {
    final raw = await _invoke<Map<Object?, Object?>>('sendMessage', {
      'recipients': recipients.map((a) => a.raw).toList(),
      'body': body,
      'attachments': attachments.map(_draftToWire).toList(),
      'subscriptionId': subscriptionId,
    });
    if (raw == null) throw const MessageSendFailedException();
    return _message(_map(raw));
  }

  Future<void> deleteMessage(String messageId) =>
      _invoke<void>('deleteMessage', {'id': messageId});

  // ---------------------------------------------------------- pièces jointes

  /// Ouvre le sélecteur de la plateforme et attend son verdict. Une liste vide
  /// signifie « annulé », pas « erreur ».
  Future<List<AttachmentDraft>> pickAttachments(AttachmentSource source) async {
    final raw = await _invoke<List<Object?>>('pickAttachments', {
      'source': source.name,
    });
    return (raw ?? const []).map((e) => _draft(_map(e))).toList();
  }

  /// Octets d'une partie du stock (`content://mms/part/<id>`).
  Future<Uint8List?> readAttachment(String attachmentId) =>
      _invoke<Uint8List>('readAttachment', {'id': attachmentId});

  /// Confie une partie du stock à l'application du système qui sait l'ouvrir.
  /// Rend `false` quand aucune ne s'en charge.
  Future<bool> openAttachment(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  }) async =>
      await _invoke<bool>('openAttachment', {
        'id': attachmentId,
        'mimeType': mimeType,
        'fileName': fileName,
      }) ??
      false;

  /// Enregistre une partie du stock dans le fichier que l'utilisateur choisit.
  /// Rend `false` s'il renonce ou si l'écriture échoue.
  Future<bool> saveAttachment(
    String attachmentId, {
    required String mimeType,
    String? fileName,
  }) async =>
      await _invoke<bool>('saveAttachment', {
        'id': attachmentId,
        'mimeType': mimeType,
        'fileName': fileName,
      }) ??
      false;

  /// Octets d'une pièce jointe encore en rédaction, désignée par son URI.
  Future<Uint8List?> readAttachmentUri(String uri) =>
      _invoke<Uint8List>('readAttachmentUri', {'uri': uri});

  /// Supprime la copie temporaire qu'une sélection a laissée (photo prise puis
  /// retirée du plateau). Sans effet sur un fichier que l'app ne possède pas.
  Future<void> discardAttachment(String uri) =>
      _invoke<void>('discardAttachment', {'uri': uri});

  /// Taille maximale d'un MMS selon la configuration opérateur, en octets.
  /// Null quand le système ne publie rien d'exploitable.
  Future<int?> mmsMaxMessageSize() =>
      _invoke<int>('mmsMaxMessageSize');

  /// Réduit une image pour qu'elle tienne sous [targetBytes].
  ///
  /// Part de `sourceUri` — l'original — et non de ce qui a déjà été compressé.
  /// Rend `null` quand la cible est hors d'atteinte.
  Future<AttachmentDraft?> compressAttachment(
    AttachmentDraft draft, {
    required int targetBytes,
  }) async {
    final raw = await _invoke<Map<Object?, Object?>>('compressAttachment', {
      'uri': draft.sourceUri,
      'mimeType': draft.mimeType,
      'targetBytes': targetBytes,
    });
    if (raw == null) return null;
    final data = _map(raw);
    return draft.compressedTo(
      uri: data['uri'] as String,
      byteSize: (data['byteSize'] as int?) ?? 0,
      mimeType: data['mimeType'] as String?,
      width: data['width'] as int?,
      height: data['height'] as int?,
    );
  }

  // ------------------------------------------------------ notifications

  /// Fils en sourdine, relus par le récepteur `SMS_DELIVER` au moment de
  /// notifier.
  Future<void> setMutedThreads(Set<String> threadIds) =>
      _invoke<void>('setMutedThreads', {'threadIds': threadIds.toList()});

  /// Annuaire `clé d'adresse → nom`, pour que la notification porte un nom.
  Future<void> setNotificationDirectory(Map<String, String> namesByAddressKey) =>
      _invoke<void>('setNotificationDirectory', {'names': namesByAddressKey});

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
      .handleError((Object e, StackTrace stack) => _streamFailed('compose', e, stack));

  // ------------------------------------------------------------ événements

  /// Flux des changements du stock. Une erreur de plateforme est absorbée : une
  /// source muette dégrade le rafraîchissement, elle ne casse pas l'app.
  Stream<SmsEvent> events() => _eventChannel
      .receiveBroadcastStream()
      .map((raw) => _event(_map(raw)))
      .where((event) => event != null)
      .cast<SmsEvent>()
      .handleError((Object e, StackTrace stack) => _streamFailed('events', e, stack));

  /// Une erreur de flux est absorbée — une source muette dégrade le
  /// rafraîchissement, elle ne casse pas l'app — mais elle ne doit pas être
  /// *invisible* : sans ce log, une liste qui cesse de se mettre à jour toute
  /// seule ne laisse aucune trace.
  void _streamFailed(String stream, Object error, StackTrace stack) {
    _logger?.error(
      'sms.stream_failed',
      attrs: {'sms.stream': stream},
      error: error,
      stack: stack,
    );
  }

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
      lastAttachmentKind: _attachmentKind(
        data['lastAttachmentMimeType'] as String?,
      ),
    );
  }

  /// Le dernier message du fil portait-il une pièce jointe, et de quelle
  /// nature ? Null pour un fil dont le dernier message est un SMS.
  AttachmentKind? _attachmentKind(String? mimeType) =>
      mimeType == null || mimeType.isEmpty
      ? null
      : AttachmentKind.fromMimeType(mimeType);

  Map<String, Object?> _draftToWire(AttachmentDraft draft) => {
    'id': draft.id,
    'uri': draft.uri,
    'sourceUri': draft.sourceUri,
    'mimeType': draft.mimeType,
    'fileName': draft.fileName,
    'byteSize': draft.byteSize,
    'width': draft.width,
    'height': draft.height,
  };

  AttachmentDraft _draft(Map<String, Object?> data) => AttachmentDraft(
    id: data['id'] as String,
    uri: data['uri'] as String,
    sourceUri: data['sourceUri'] as String?,
    mimeType: (data['mimeType'] as String?) ?? 'application/octet-stream',
    fileName: (data['fileName'] as String?) ?? 'Pièce jointe',
    byteSize: (data['byteSize'] as int?) ?? 0,
    width: data['width'] as int?,
    height: data['height'] as int?,
  );

  Attachment _attachment(Map<String, Object?> data) => Attachment(
    id: data['id'] as String,
    // Une partie sans type déclaré existe : on la traite en fichier opaque
    // plutôt que de la laisser tomber du message.
    mimeType: (data['mimeType'] as String?)?.trim().isNotEmpty == true
        ? data['mimeType'] as String
        : 'application/octet-stream',
    fileName: data['fileName'] as String?,
    byteSize: (data['byteSize'] as int?) ?? 0,
    width: data['width'] as int?,
    height: data['height'] as int?,
    durationMs: data['durationMs'] as int?,
  );

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
      attachments: (data['attachments'] as List<Object?>? ?? const [])
          .map((e) => _attachment(_map(e)))
          .toList(),
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
      canNotify: data['canNotify'] == true,
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
    } on PlatformException catch (e, stack) {
      // Un refus attendu (rôle manquant, permission non accordée) est un
      // `warn` : l'app est dans un état connu et l'écran le dit déjà. Tout le
      // reste est un `error` — le natif a rencontré quelque chose que
      // personne n'a prévu.
      final expected = const {
        'not_default_sms_app',
        'permission_denied',
        'not_found',
        'attachment_too_large',
        'attachment_unavailable',
      }.contains(e.code);
      _log(
        expected,
        'sms.platform_error',
        attrs: {
          'sms.method': method,
          'sms.error_code': e.code,
          if (e.message != null) 'sms.error_message': e.message,
        },
        error: e,
        stack: stack,
      );
      throw switch (e.code) {
        'not_default_sms_app' => const NotDefaultSmsAppException(),
        'permission_denied' => const SmsPermissionDeniedException(),
        'not_found' => const MessageNotFoundException(),
        // Le natif refuse sans connaître la limite négociée côté Dart : on
        // annonce le repli, faute de mieux.
        'attachment_too_large' => AttachmentTooLargeException(
          MmsLimits.fallback,
        ),
        'attachment_unavailable' => const AttachmentUnavailableException(),
        _ => MessageSendFailedException(e.message),
      };
    } on MissingPluginException catch (e, stack) {
      // Le canal n'existe que sur Android : ailleurs, l'assemblage des
      // providers choisit déjà les doublures InMemory. Un appel qui arrive
      // quand même ici est un bug de câblage, pas une erreur utilisateur — et
      // il se présente à l'utilisateur comme une permission refusée, ce qui
      // est le pire des déguisements. D'où le niveau `error`.
      _log(
        false,
        'sms.channel_missing',
        attrs: {'sms.method': method},
        error: e,
        stack: stack,
      );
      throw const SmsPermissionDeniedException();
    }
  }

  void _log(
    bool expected,
    String message, {
    required Map<String, Object?> attrs,
    Object? error,
    StackTrace? stack,
  }) {
    final logger = _logger;
    if (logger == null) return;
    if (expected) {
      logger.warn(message, attrs: attrs, error: error, stack: stack);
    } else {
      logger.error(message, attrs: attrs, error: error, stack: stack);
    }
  }
}
