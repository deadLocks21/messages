// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Assemblage des ports : implémentation Android sur téléphone, doublures
/// InMemory partout ailleurs. C'est le seul endroit qui connaît les deux.

@ProviderFor(conversationRepository)
final conversationRepositoryProvider = ConversationRepositoryProvider._();

/// Assemblage des ports : implémentation Android sur téléphone, doublures
/// InMemory partout ailleurs. C'est le seul endroit qui connaît les deux.

final class ConversationRepositoryProvider
    extends
        $FunctionalProvider<
          ConversationRepository,
          ConversationRepository,
          ConversationRepository
        >
    with $Provider<ConversationRepository> {
  /// Assemblage des ports : implémentation Android sur téléphone, doublures
  /// InMemory partout ailleurs. C'est le seul endroit qui connaît les deux.
  ConversationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConversationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConversationRepository create(Ref ref) {
    return conversationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationRepository>(value),
    );
  }
}

String _$conversationRepositoryHash() =>
    r'86eda20ff4dca9c57126d43781da43d02673d87a';

@ProviderFor(messageRepository)
final messageRepositoryProvider = MessageRepositoryProvider._();

final class MessageRepositoryProvider
    extends
        $FunctionalProvider<
          MessageRepository,
          MessageRepository,
          MessageRepository
        >
    with $Provider<MessageRepository> {
  MessageRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageRepositoryHash();

  @$internal
  @override
  $ProviderElement<MessageRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MessageRepository create(Ref ref) {
    return messageRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageRepository>(value),
    );
  }
}

String _$messageRepositoryHash() => r'94d0c2f7533e94cff368cdc3283f963a873c52b7';

@ProviderFor(attachmentRepository)
final attachmentRepositoryProvider = AttachmentRepositoryProvider._();

final class AttachmentRepositoryProvider
    extends
        $FunctionalProvider<
          AttachmentRepository,
          AttachmentRepository,
          AttachmentRepository
        >
    with $Provider<AttachmentRepository> {
  AttachmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<AttachmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentRepository create(Ref ref) {
    return attachmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentRepository>(value),
    );
  }
}

String _$attachmentRepositoryHash() =>
    r'f8fe763169cac99841d091c3ffe732a7d6b228a2';

@ProviderFor(attachmentPicker)
final attachmentPickerProvider = AttachmentPickerProvider._();

final class AttachmentPickerProvider
    extends
        $FunctionalProvider<
          AttachmentPicker,
          AttachmentPicker,
          AttachmentPicker
        >
    with $Provider<AttachmentPicker> {
  AttachmentPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentPickerHash();

  @$internal
  @override
  $ProviderElement<AttachmentPicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttachmentPicker create(Ref ref) {
    return attachmentPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentPicker>(value),
    );
  }
}

String _$attachmentPickerHash() => r'38874b0feae8689fc3185a17ee28ddc32e2f0799';

@ProviderFor(contactRepository)
final contactRepositoryProvider = ContactRepositoryProvider._();

final class ContactRepositoryProvider
    extends
        $FunctionalProvider<
          ContactRepository,
          ContactRepository,
          ContactRepository
        >
    with $Provider<ContactRepository> {
  ContactRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contactRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contactRepositoryHash();

  @$internal
  @override
  $ProviderElement<ContactRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContactRepository create(Ref ref) {
    return contactRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContactRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContactRepository>(value),
    );
  }
}

String _$contactRepositoryHash() => r'6f7ff898ea8e721a2d8e0b00bdcd1191d8ffef85';

@ProviderFor(smsPermissionsService)
final smsPermissionsServiceProvider = SmsPermissionsServiceProvider._();

final class SmsPermissionsServiceProvider
    extends
        $FunctionalProvider<
          SmsPermissionsService,
          SmsPermissionsService,
          SmsPermissionsService
        >
    with $Provider<SmsPermissionsService> {
  SmsPermissionsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smsPermissionsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smsPermissionsServiceHash();

  @$internal
  @override
  $ProviderElement<SmsPermissionsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SmsPermissionsService create(Ref ref) {
    return smsPermissionsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmsPermissionsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmsPermissionsService>(value),
    );
  }
}

String _$smsPermissionsServiceHash() =>
    r'b83b0f592191e44e5b749d04aaf139c5314a4c10';

@ProviderFor(notificationGateway)
final notificationGatewayProvider = NotificationGatewayProvider._();

final class NotificationGatewayProvider
    extends
        $FunctionalProvider<
          NotificationGateway,
          NotificationGateway,
          NotificationGateway
        >
    with $Provider<NotificationGateway> {
  NotificationGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationGatewayHash();

  @$internal
  @override
  $ProviderElement<NotificationGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationGateway create(Ref ref) {
    return notificationGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationGateway>(value),
    );
  }
}

String _$notificationGatewayHash() =>
    r'475499c4927501d05c9d6662d638737366abad28';

/// Les réglages locaux (épinglage, brouillons, thème) sont persistés de la même
/// façon sur toutes les plateformes : `shared_preferences` a une implémentation
/// partout, doublure inutile.

@ProviderFor(conversationPreferencesRepository)
final conversationPreferencesRepositoryProvider =
    ConversationPreferencesRepositoryProvider._();

/// Les réglages locaux (épinglage, brouillons, thème) sont persistés de la même
/// façon sur toutes les plateformes : `shared_preferences` a une implémentation
/// partout, doublure inutile.

final class ConversationPreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          ConversationPreferencesRepository,
          ConversationPreferencesRepository,
          ConversationPreferencesRepository
        >
    with $Provider<ConversationPreferencesRepository> {
  /// Les réglages locaux (épinglage, brouillons, thème) sont persistés de la même
  /// façon sur toutes les plateformes : `shared_preferences` a une implémentation
  /// partout, doublure inutile.
  ConversationPreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationPreferencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$conversationPreferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConversationPreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConversationPreferencesRepository create(Ref ref) {
    return conversationPreferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationPreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationPreferencesRepository>(
        value,
      ),
    );
  }
}

String _$conversationPreferencesRepositoryHash() =>
    r'940bba9d9ba5bbdcdbe93e42f1998b62de153173';

@ProviderFor(draftRepository)
final draftRepositoryProvider = DraftRepositoryProvider._();

final class DraftRepositoryProvider
    extends
        $FunctionalProvider<DraftRepository, DraftRepository, DraftRepository>
    with $Provider<DraftRepository> {
  DraftRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftRepositoryHash();

  @$internal
  @override
  $ProviderElement<DraftRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DraftRepository create(Ref ref) {
    return draftRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DraftRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DraftRepository>(value),
    );
  }
}

String _$draftRepositoryHash() => r'776ffbdd7392fc14dbda0aa3bc501ec329a87555';

@ProviderFor(themeRepository)
final themeRepositoryProvider = ThemeRepositoryProvider._();

final class ThemeRepositoryProvider
    extends
        $FunctionalProvider<ThemeRepository, ThemeRepository, ThemeRepository>
    with $Provider<ThemeRepository> {
  ThemeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeRepositoryHash();

  @$internal
  @override
  $ProviderElement<ThemeRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeRepository create(Ref ref) {
    return themeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeRepository>(value),
    );
  }
}

String _$themeRepositoryHash() => r'a948ece27b72bfc7a1e94052873d117823355140';
