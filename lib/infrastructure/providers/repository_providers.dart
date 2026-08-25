import 'package:messages/core/domain/services/contact.repository.dart';
import 'package:messages/core/domain/services/conversation.repository.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:messages/core/domain/services/draft.repository.dart';
import 'package:messages/core/domain/services/message.repository.dart';
import 'package:messages/core/domain/services/notification.gateway.dart';
import 'package:messages/core/domain/services/sms_permissions.service.dart';
import 'package:messages/core/domain/services/theme.repository.dart';
import 'package:messages/infrastructure/contacts/flutter_contacts.contact.repository.dart';
import 'package:messages/infrastructure/notifications/android.notification.gateway.dart';
import 'package:messages/infrastructure/notifications/in_memory.notification.gateway.dart';
import 'package:messages/infrastructure/permissions/in_memory.sms_permissions.service.dart';
import 'package:messages/infrastructure/permissions/permission_handler.sms_permissions.service.dart';
import 'package:messages/infrastructure/preferences/shared_preferences.conversation_preferences.repository.dart';
import 'package:messages/infrastructure/preferences/shared_preferences.draft.repository.dart';
import 'package:messages/infrastructure/preferences/shared_preferences.theme.repository.dart';
import 'package:messages/infrastructure/providers/infra_providers.dart';
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
    SharedPreferencesConversationPreferencesRepository();

@Riverpod(keepAlive: true)
DraftRepository draftRepository(Ref ref) => SharedPreferencesDraftRepository();

@Riverpod(keepAlive: true)
ThemeRepository themeRepository(Ref ref) => SharedPreferencesThemeRepository();
