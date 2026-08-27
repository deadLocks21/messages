import 'package:messages/core/domain/services/attachment.repository.dart';
import 'package:messages/core/domain/services/attachment_compressor.service.dart';
import 'package:messages/core/domain/services/attachment_picker.service.dart';
import 'package:messages/core/domain/services/audio_player.service.dart';
import 'package:messages/core/domain/services/audio_waveform.service.dart';
import 'package:messages/core/domain/services/mms_configuration.service.dart';
import 'package:messages/core/domain/services/contact.repository.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/domain/services/draft.repository.dart';
import 'package:messages/core/domain/services/message.repository.dart';
import 'package:messages/core/domain/services/notification.gateway.dart';
import 'package:messages/core/domain/services/sms_permissions.service.dart';
import 'package:messages/core/domain/services/theme.repository.dart';
import 'package:messages/infrastructure/attachments/android.attachment.repository.dart';
import 'package:messages/infrastructure/attachments/android.attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/android.attachment_picker.service.dart';
import 'package:messages/infrastructure/attachments/android.mms_configuration.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment.repository.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_compressor.service.dart';
import 'package:messages/infrastructure/attachments/in_memory.mms_configuration.service.dart';
import 'package:messages/infrastructure/audio/android.audio_player.service.dart';
import 'package:messages/infrastructure/audio/android.audio_waveform.service.dart';
import 'package:messages/infrastructure/audio/in_memory.audio_player.service.dart';
import 'package:messages/infrastructure/audio/in_memory.audio_waveform.service.dart';
import 'package:messages/infrastructure/contacts/flutter_contacts.contact.repository.dart';
import 'package:messages/infrastructure/notifications/android.notification.gateway.dart';
import 'package:messages/infrastructure/notifications/in_memory.notification.gateway.dart';
import 'package:messages/infrastructure/permissions/in_memory.sms_permissions.service.dart';
import 'package:messages/infrastructure/permissions/permission_handler.sms_permissions.service.dart';
import 'package:messages/infrastructure/preferences/shared_preferences.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/shared_preferences.draft.repository.dart';
import 'package:messages/infrastructure/preferences/shared_preferences.theme.repository.dart';
import 'package:messages/infrastructure/providers/infra_providers.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/sms/android.conversation.repository.dart';
import 'package:messages/infrastructure/sms/android.message.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.conversation.repository.dart';
import 'package:messages/infrastructure/sms/in_memory.message.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repository_providers.g.dart';

/// Assemblage des ports : implémentation Android sur téléphone, doublures
/// InMemory partout ailleurs. C'est le seul endroit qui connaît les deux.

@Riverpod(keepAlive: true)
ConversationRepository conversationRepository(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidConversationRepository(ref.watch(smsChannelProvider));
  }
  return InMemoryConversationRepository(ref.watch(inMemorySmsStoreProvider));
}

@Riverpod(keepAlive: true)
MessageRepository messageRepository(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidMessageRepository(ref.watch(smsChannelProvider));
  }
  return InMemoryMessageRepository(ref.watch(inMemorySmsStoreProvider));
}

@Riverpod(keepAlive: true)
AttachmentRepository attachmentRepository(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidAttachmentRepository(ref.watch(smsChannelProvider));
  }
  return InMemoryAttachmentRepository(ref.watch(inMemorySmsStoreProvider));
}

/// Lecteur des vocaux. `keepAlive` : un son continue de jouer quand on quitte
/// le fil pour la liste, comme dans l'app d'origine.
@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidAudioPlayerService(logger: ref.watch(loggerProvider));
  }
  final player = InMemoryAudioPlayerService(ref.watch(inMemorySmsStoreProvider));
  ref.onDispose(player.dispose);
  return player;
}

/// Mesure de la silhouette des vocaux. Le cache est côté natif, là où se
/// trouve le coût : décoder deux fois le même vocal ne dirait rien de plus.
@Riverpod(keepAlive: true)
AudioWaveformService audioWaveformService(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return const AndroidAudioWaveformService();
  }
  return const InMemoryAudioWaveformService();
}

@Riverpod(keepAlive: true)
AttachmentPicker attachmentPicker(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidAttachmentPicker(ref.watch(smsChannelProvider));
  }
  return ref.watch(inMemoryAttachmentPickerProvider);
}

@Riverpod(keepAlive: true)
AttachmentCompressor attachmentCompressor(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidAttachmentCompressor(ref.watch(smsChannelProvider));
  }
  return InMemoryAttachmentCompressor(ref.watch(inMemorySmsStoreProvider));
}

/// Configuration MMS de l'opérateur. `keepAlive` : c'est ce qui fait tenir le
/// cache — la limite est lue une fois pour toute la session.
@Riverpod(keepAlive: true)
MmsConfiguration mmsConfiguration(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidMmsConfiguration(
      ref.watch(smsChannelProvider),
      logger: ref.watch(loggerProvider),
    );
  }
  return InMemoryMmsConfiguration();
}

@Riverpod(keepAlive: true)
ContactRepository contactRepository(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return const FlutterContactsContactRepository();
  }
  return ref.watch(inMemoryContactsProvider);
}

@Riverpod(keepAlive: true)
SmsPermissionsService smsPermissionsService(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return PermissionHandlerSmsPermissionsService(ref.watch(smsChannelProvider));
  }
  // Hors Android, tout est permis : la démo ne doit pas buter sur un écran
  // d'autorisations qui n'aurait rien à demander.
  return InMemorySmsPermissionsService();
}

@Riverpod(keepAlive: true)
NotificationGateway notificationGateway(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidNotificationGateway(ref.watch(smsChannelProvider));
  }
  return InMemoryNotificationGateway();
}

/// Les réglages locaux (épinglage, brouillons, thème) sont persistés de la même
/// façon sur toutes les plateformes : `shared_preferences` a une implémentation
/// partout, doublure inutile.

@Riverpod(keepAlive: true)
ConversationPreferencesRepository conversationPreferencesRepository(Ref ref) =>
    SharedPreferencesConversationPreferencesRepository(
      logger: ref.watch(loggerProvider),
    );

@Riverpod(keepAlive: true)
DraftRepository draftRepository(Ref ref) =>
    SharedPreferencesDraftRepository(logger: ref.watch(loggerProvider));

@Riverpod(keepAlive: true)
ThemeRepository themeRepository(Ref ref) => SharedPreferencesThemeRepository();
