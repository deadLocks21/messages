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

/// Lecteur des vocaux. `keepAlive` : un son continue de jouer quand on quitte
/// le fil pour la liste, comme dans l'app d'origine.

@ProviderFor(audioPlayerService)
final audioPlayerServiceProvider = AudioPlayerServiceProvider._();

/// Lecteur des vocaux. `keepAlive` : un son continue de jouer quand on quitte
/// le fil pour la liste, comme dans l'app d'origine.

final class AudioPlayerServiceProvider
    extends
        $FunctionalProvider<
          AudioPlayerService,
          AudioPlayerService,
          AudioPlayerService
        >
    with $Provider<AudioPlayerService> {
  /// Lecteur des vocaux. `keepAlive` : un son continue de jouer quand on quitte
  /// le fil pour la liste, comme dans l'app d'origine.
  AudioPlayerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlayerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlayerServiceHash();

  @$internal
  @override
  $ProviderElement<AudioPlayerService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioPlayerService create(Ref ref) {
    return audioPlayerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlayerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlayerService>(value),
    );
  }
}

String _$audioPlayerServiceHash() =>
    r'08c0de25b0b73261f4e772e91ef1511c2469a1ef';

/// Enregistreur de vocaux. `keepAlive`, comme le lecteur : un enregistrement
/// en cours ne doit pas s'interrompre parce qu'un écran s'est reconstruit.

@ProviderFor(audioRecorderService)
final audioRecorderServiceProvider = AudioRecorderServiceProvider._();

/// Enregistreur de vocaux. `keepAlive`, comme le lecteur : un enregistrement
/// en cours ne doit pas s'interrompre parce qu'un écran s'est reconstruit.

final class AudioRecorderServiceProvider
    extends
        $FunctionalProvider<
          AudioRecorderService,
          AudioRecorderService,
          AudioRecorderService
        >
    with $Provider<AudioRecorderService> {
  /// Enregistreur de vocaux. `keepAlive`, comme le lecteur : un enregistrement
  /// en cours ne doit pas s'interrompre parce qu'un écran s'est reconstruit.
  AudioRecorderServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioRecorderServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioRecorderServiceHash();

  @$internal
  @override
  $ProviderElement<AudioRecorderService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioRecorderService create(Ref ref) {
    return audioRecorderService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioRecorderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioRecorderService>(value),
    );
  }
}

String _$audioRecorderServiceHash() =>
    r'6a86e3b42f2632dc0a6d8433df9162ebbffac2eb';

/// Ce que l'app ne sait pas montrer, elle le confie : PDF, vidéo, vCard.

@ProviderFor(attachmentOpener)
final attachmentOpenerProvider = AttachmentOpenerProvider._();

/// Ce que l'app ne sait pas montrer, elle le confie : PDF, vidéo, vCard.

final class AttachmentOpenerProvider
    extends
        $FunctionalProvider<
          AttachmentOpener,
          AttachmentOpener,
          AttachmentOpener
        >
    with $Provider<AttachmentOpener> {
  /// Ce que l'app ne sait pas montrer, elle le confie : PDF, vidéo, vCard.
  AttachmentOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentOpenerHash();

  @$internal
  @override
  $ProviderElement<AttachmentOpener> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AttachmentOpener create(Ref ref) {
    return attachmentOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentOpener>(value),
    );
  }
}

String _$attachmentOpenerHash() => r'3285d8f4674a2ac15c6b0e61dec24da6e42ea00d';

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

/// Rapatriement d'un média distant — le GIF choisi dans le catalogue.

@ProviderFor(mediaDownloader)
final mediaDownloaderProvider = MediaDownloaderProvider._();

/// Rapatriement d'un média distant — le GIF choisi dans le catalogue.

final class MediaDownloaderProvider
    extends
        $FunctionalProvider<MediaDownloader, MediaDownloader, MediaDownloader>
    with $Provider<MediaDownloader> {
  /// Rapatriement d'un média distant — le GIF choisi dans le catalogue.
  MediaDownloaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaDownloaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaDownloaderHash();

  @$internal
  @override
  $ProviderElement<MediaDownloader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaDownloader create(Ref ref) {
    return mediaDownloader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaDownloader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaDownloader>(value),
    );
  }
}

String _$mediaDownloaderHash() => r'eb0b3489c4904feedf992e69b502adc4eb8e2b5a';

/// Catalogue de GIF.
///
/// Klipy **si une clé a été fournie à la compilation**, doublure sinon — la
/// même règle que Signoz, et pour la même raison : une clé d'API n'a rien à
/// faire dans un dépôt, et une app qui ne peut pas la lire doit rester
/// développable.
///
/// ```bash
/// flutter run --dart-define=KLIPY_API_KEY=<clé>
/// ```
///
/// `keepAlive` : l'adaptateur tient un client HTTP, qu'il serait absurde de
/// reconstruire à chaque frappe dans le champ de recherche.

@ProviderFor(gifCatalog)
final gifCatalogProvider = GifCatalogProvider._();

/// Catalogue de GIF.
///
/// Klipy **si une clé a été fournie à la compilation**, doublure sinon — la
/// même règle que Signoz, et pour la même raison : une clé d'API n'a rien à
/// faire dans un dépôt, et une app qui ne peut pas la lire doit rester
/// développable.
///
/// ```bash
/// flutter run --dart-define=KLIPY_API_KEY=<clé>
/// ```
///
/// `keepAlive` : l'adaptateur tient un client HTTP, qu'il serait absurde de
/// reconstruire à chaque frappe dans le champ de recherche.

final class GifCatalogProvider
    extends $FunctionalProvider<GifCatalog, GifCatalog, GifCatalog>
    with $Provider<GifCatalog> {
  /// Catalogue de GIF.
  ///
  /// Klipy **si une clé a été fournie à la compilation**, doublure sinon — la
  /// même règle que Signoz, et pour la même raison : une clé d'API n'a rien à
  /// faire dans un dépôt, et une app qui ne peut pas la lire doit rester
  /// développable.
  ///
  /// ```bash
  /// flutter run --dart-define=KLIPY_API_KEY=<clé>
  /// ```
  ///
  /// `keepAlive` : l'adaptateur tient un client HTTP, qu'il serait absurde de
  /// reconstruire à chaque frappe dans le champ de recherche.
  GifCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gifCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gifCatalogHash();

  @$internal
  @override
  $ProviderElement<GifCatalog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GifCatalog create(Ref ref) {
    return gifCatalog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GifCatalog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GifCatalog>(value),
    );
  }
}

String _$gifCatalogHash() => r'350743c2a7d35b6a89381ebe9e6055b12f6e884f';

@ProviderFor(attachmentCompressor)
final attachmentCompressorProvider = AttachmentCompressorProvider._();

final class AttachmentCompressorProvider
    extends
        $FunctionalProvider<
          AttachmentCompressor,
          AttachmentCompressor,
          AttachmentCompressor
        >
    with $Provider<AttachmentCompressor> {
  AttachmentCompressorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentCompressorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentCompressorHash();

  @$internal
  @override
  $ProviderElement<AttachmentCompressor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AttachmentCompressor create(Ref ref) {
    return attachmentCompressor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentCompressor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentCompressor>(value),
    );
  }
}

String _$attachmentCompressorHash() =>
    r'2a1cf244af1f7ae3c43406f6076b83fc2c3469d6';

/// Configuration MMS de l'opérateur. `keepAlive` : c'est ce qui fait tenir le
/// cache — la limite est lue une fois pour toute la session.

@ProviderFor(mmsConfiguration)
final mmsConfigurationProvider = MmsConfigurationProvider._();

/// Configuration MMS de l'opérateur. `keepAlive` : c'est ce qui fait tenir le
/// cache — la limite est lue une fois pour toute la session.

final class MmsConfigurationProvider
    extends
        $FunctionalProvider<
          MmsConfiguration,
          MmsConfiguration,
          MmsConfiguration
        >
    with $Provider<MmsConfiguration> {
  /// Configuration MMS de l'opérateur. `keepAlive` : c'est ce qui fait tenir le
  /// cache — la limite est lue une fois pour toute la session.
  MmsConfigurationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mmsConfigurationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mmsConfigurationHash();

  @$internal
  @override
  $ProviderElement<MmsConfiguration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MmsConfiguration create(Ref ref) {
    return mmsConfiguration(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MmsConfiguration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MmsConfiguration>(value),
    );
  }
}

String _$mmsConfigurationHash() => r'eb08bb77f02221537170a11538231273f674f4b2';

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
    r'83c0f90c6649ee12bbc2b891e142823fa37d9d7b';

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

String _$draftRepositoryHash() => r'74b5bf404875f33f46220a48aba43f275edc8ca4';

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

/// Le repli des réactions se coupe depuis les réglages : c'est le filet quand
/// la reconnaissance d'une phrase se trompe.

@ProviderFor(reactionPreferencesRepository)
final reactionPreferencesRepositoryProvider =
    ReactionPreferencesRepositoryProvider._();

/// Le repli des réactions se coupe depuis les réglages : c'est le filet quand
/// la reconnaissance d'une phrase se trompe.

final class ReactionPreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          ReactionPreferencesRepository,
          ReactionPreferencesRepository,
          ReactionPreferencesRepository
        >
    with $Provider<ReactionPreferencesRepository> {
  /// Le repli des réactions se coupe depuis les réglages : c'est le filet quand
  /// la reconnaissance d'une phrase se trompe.
  ReactionPreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reactionPreferencesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reactionPreferencesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReactionPreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReactionPreferencesRepository create(Ref ref) {
    return reactionPreferencesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReactionPreferencesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReactionPreferencesRepository>(
        value,
      ),
    );
  }
}

String _$reactionPreferencesRepositoryHash() =>
    r'e9e8c414a0d7432ea516b0e18dd16efed46b6a65';

/// Emoji récemment utilisés. `keepAlive` : c'est de la préférence, elle vit
/// aussi longtemps que l'app.

@ProviderFor(emojiHistoryRepository)
final emojiHistoryRepositoryProvider = EmojiHistoryRepositoryProvider._();

/// Emoji récemment utilisés. `keepAlive` : c'est de la préférence, elle vit
/// aussi longtemps que l'app.

final class EmojiHistoryRepositoryProvider
    extends
        $FunctionalProvider<
          EmojiHistoryRepository,
          EmojiHistoryRepository,
          EmojiHistoryRepository
        >
    with $Provider<EmojiHistoryRepository> {
  /// Emoji récemment utilisés. `keepAlive` : c'est de la préférence, elle vit
  /// aussi longtemps que l'app.
  EmojiHistoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emojiHistoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emojiHistoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<EmojiHistoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmojiHistoryRepository create(Ref ref) {
    return emojiHistoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmojiHistoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmojiHistoryRepository>(value),
    );
  }
}

String _$emojiHistoryRepositoryHash() =>
    r'af351cd6449da5d2dc3a5004c8bc5ae4ae10ad6c';
