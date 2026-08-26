import 'package:messages/core/application/services/contact_directory.service.dart';
import 'package:messages/core/application/services/contact_picker.service.dart';
import 'package:messages/core/application/services/conversation_list.service.dart';
import 'package:messages/core/application/services/conversation_timeline.service.dart';
import 'package:messages/core/application/services/search.service.dart';
import 'package:messages/core/application/usecases/delete_conversation.usecase.dart';
import 'package:messages/core/application/usecases/delete_message.usecase.dart';
import 'package:messages/core/application/usecases/mark_conversation_read.usecase.dart';
import 'package:messages/core/application/usecases/pick_attachments.usecase.dart';
import 'package:messages/core/application/usecases/request_sms_access.usecase.dart';
import 'package:messages/core/application/usecases/resend_message.usecase.dart';
import 'package:messages/core/application/usecases/save_draft.usecase.dart';
import 'package:messages/core/application/usecases/send_message.usecase.dart';
import 'package:messages/core/application/usecases/start_conversation.usecase.dart';
import 'package:messages/core/application/usecases/sync_notification_settings.usecase.dart';
import 'package:messages/core/application/usecases/update_conversation_flags.usecase.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'service_providers.g.dart';

// ------------------------------------------------------------- services

@Riverpod(keepAlive: true)
ContactDirectoryService contactDirectoryService(Ref ref) =>
    ContactDirectoryService(ref.watch(contactRepositoryProvider));

@Riverpod(keepAlive: true)
ContactPickerService contactPickerService(Ref ref) =>
    ContactPickerService(ref.watch(contactDirectoryServiceProvider));

@Riverpod(keepAlive: true)
ConversationListService conversationListService(Ref ref) =>
    ConversationListService(
      conversations: ref.watch(conversationRepositoryProvider),
      directory: ref.watch(contactDirectoryServiceProvider),
      preferences: ref.watch(conversationPreferencesRepositoryProvider),
      drafts: ref.watch(draftRepositoryProvider),
    );

@Riverpod(keepAlive: true)
ConversationTimelineService conversationTimelineService(Ref ref) =>
    ConversationTimelineService(
      messages: ref.watch(messageRepositoryProvider),
      directory: ref.watch(contactDirectoryServiceProvider),
    );

@Riverpod(keepAlive: true)
SearchService searchService(Ref ref) => SearchService(
  conversations: ref.watch(conversationListServiceProvider),
  messages: ref.watch(messageRepositoryProvider),
);

// ------------------------------------------------------------- usecases

@Riverpod(keepAlive: true)
SendMessageUseCase sendMessageUseCase(Ref ref) => SendMessageUseCase(
  messages: ref.watch(messageRepositoryProvider),
  drafts: ref.watch(draftRepositoryProvider),
);

@Riverpod(keepAlive: true)
PickAttachmentsUseCase pickAttachmentsUseCase(Ref ref) =>
    PickAttachmentsUseCase(ref.watch(attachmentPickerProvider));

@Riverpod(keepAlive: true)
ResendMessageUseCase resendMessageUseCase(Ref ref) =>
    ResendMessageUseCase(ref.watch(messageRepositoryProvider));

@Riverpod(keepAlive: true)
DeleteMessageUseCase deleteMessageUseCase(Ref ref) =>
    DeleteMessageUseCase(ref.watch(messageRepositoryProvider));

@Riverpod(keepAlive: true)
MarkConversationReadUseCase markConversationReadUseCase(Ref ref) =>
    MarkConversationReadUseCase(ref.watch(conversationRepositoryProvider));

@Riverpod(keepAlive: true)
DeleteConversationUseCase deleteConversationUseCase(Ref ref) =>
    DeleteConversationUseCase(
      conversations: ref.watch(conversationRepositoryProvider),
      preferences: ref.watch(conversationPreferencesRepositoryProvider),
      drafts: ref.watch(draftRepositoryProvider),
    );

@Riverpod(keepAlive: true)
UpdateConversationFlagsUseCase updateConversationFlagsUseCase(Ref ref) =>
    UpdateConversationFlagsUseCase(
      preferences: ref.watch(conversationPreferencesRepositoryProvider),
      notifications: ref.watch(syncNotificationSettingsUseCaseProvider),
    );

@Riverpod(keepAlive: true)
SyncNotificationSettingsUseCase syncNotificationSettingsUseCase(Ref ref) =>
    SyncNotificationSettingsUseCase(
      directory: ref.watch(contactDirectoryServiceProvider),
      preferences: ref.watch(conversationPreferencesRepositoryProvider),
      notifications: ref.watch(notificationGatewayProvider),
    );

@Riverpod(keepAlive: true)
SaveDraftUseCase saveDraftUseCase(Ref ref) =>
    SaveDraftUseCase(ref.watch(draftRepositoryProvider));

@Riverpod(keepAlive: true)
StartConversationUseCase startConversationUseCase(Ref ref) =>
    StartConversationUseCase(ref.watch(conversationRepositoryProvider));

@Riverpod(keepAlive: true)
RequestSmsAccessUseCase requestSmsAccessUseCase(Ref ref) =>
    RequestSmsAccessUseCase(ref.watch(smsPermissionsServiceProvider));
