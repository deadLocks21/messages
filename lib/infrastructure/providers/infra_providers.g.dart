// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'infra_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Vrai stock Telephony, ou doublure ?
///
/// Le canal natif n'existe que sur Android. Ailleurs (macOS, web, tests), l'app
/// tourne sur [InMemorySmsStore] pré-rempli par [DemoSeed] : l'UI reste
/// développable et testable sans téléphone.

@ProviderFor(useNativeSmsStack)
final useNativeSmsStackProvider = UseNativeSmsStackProvider._();

/// Vrai stock Telephony, ou doublure ?
///
/// Le canal natif n'existe que sur Android. Ailleurs (macOS, web, tests), l'app
/// tourne sur [InMemorySmsStore] pré-rempli par [DemoSeed] : l'UI reste
/// développable et testable sans téléphone.

final class UseNativeSmsStackProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Vrai stock Telephony, ou doublure ?
  ///
  /// Le canal natif n'existe que sur Android. Ailleurs (macOS, web, tests), l'app
  /// tourne sur [InMemorySmsStore] pré-rempli par [DemoSeed] : l'UI reste
  /// développable et testable sans téléphone.
  UseNativeSmsStackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'useNativeSmsStackProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$useNativeSmsStackHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return useNativeSmsStack(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$useNativeSmsStackHash() => r'c2802f2f9fad129ccbb95e36d6c583e102046341';

/// Pont vers le stock SMS d'Android.
///
/// Le logger lui est passé ici : c'est le canal qui voit passer les échecs de
/// la plateforme, et il est le seul endroit d'où ils soient tous visibles.

@ProviderFor(smsChannel)
final smsChannelProvider = SmsChannelProvider._();

/// Pont vers le stock SMS d'Android.
///
/// Le logger lui est passé ici : c'est le canal qui voit passer les échecs de
/// la plateforme, et il est le seul endroit d'où ils soient tous visibles.

final class SmsChannelProvider
    extends
        $FunctionalProvider<
          AndroidSmsChannel,
          AndroidSmsChannel,
          AndroidSmsChannel
        >
    with $Provider<AndroidSmsChannel> {
  /// Pont vers le stock SMS d'Android.
  ///
  /// Le logger lui est passé ici : c'est le canal qui voit passer les échecs de
  /// la plateforme, et il est le seul endroit d'où ils soient tous visibles.
  SmsChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smsChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smsChannelHash();

  @$internal
  @override
  $ProviderElement<AndroidSmsChannel> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AndroidSmsChannel create(Ref ref) {
    return smsChannel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AndroidSmsChannel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AndroidSmsChannel>(value),
    );
  }
}

String _$smsChannelHash() => r'fa75b1e683a4390c15cf0f24764e8d0b33bd804f';

/// Carnet d'adresses simulé, partagé par le seed et le repository InMemory.

@ProviderFor(inMemoryContacts)
final inMemoryContactsProvider = InMemoryContactsProvider._();

/// Carnet d'adresses simulé, partagé par le seed et le repository InMemory.

final class InMemoryContactsProvider
    extends
        $FunctionalProvider<
          InMemoryContactRepository,
          InMemoryContactRepository,
          InMemoryContactRepository
        >
    with $Provider<InMemoryContactRepository> {
  /// Carnet d'adresses simulé, partagé par le seed et le repository InMemory.
  InMemoryContactsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inMemoryContactsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inMemoryContactsHash();

  @$internal
  @override
  $ProviderElement<InMemoryContactRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InMemoryContactRepository create(Ref ref) {
    return inMemoryContacts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InMemoryContactRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InMemoryContactRepository>(value),
    );
  }
}

String _$inMemoryContactsHash() => r'81de0a26938d24c1ca7b7fbe6fb7766358be507e';

/// Stock SMS simulé, monté avec les données de démonstration.

@ProviderFor(inMemorySmsStore)
final inMemorySmsStoreProvider = InMemorySmsStoreProvider._();

/// Stock SMS simulé, monté avec les données de démonstration.

final class InMemorySmsStoreProvider
    extends
        $FunctionalProvider<
          InMemorySmsStore,
          InMemorySmsStore,
          InMemorySmsStore
        >
    with $Provider<InMemorySmsStore> {
  /// Stock SMS simulé, monté avec les données de démonstration.
  InMemorySmsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inMemorySmsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inMemorySmsStoreHash();

  @$internal
  @override
  $ProviderElement<InMemorySmsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InMemorySmsStore create(Ref ref) {
    return inMemorySmsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InMemorySmsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InMemorySmsStore>(value),
    );
  }
}

String _$inMemorySmsStoreHash() => r'62d064dc04a3c66053db38b5f3dbe8fc8e4faee3';

/// Ouvreur de pièces jointes simulé. Exposé à part pour que les tests puissent
/// lire ce qu'on lui a confié, et simuler un appareil qui ne sait pas l'ouvrir.

@ProviderFor(inMemoryAttachmentOpener)
final inMemoryAttachmentOpenerProvider = InMemoryAttachmentOpenerProvider._();

/// Ouvreur de pièces jointes simulé. Exposé à part pour que les tests puissent
/// lire ce qu'on lui a confié, et simuler un appareil qui ne sait pas l'ouvrir.

final class InMemoryAttachmentOpenerProvider
    extends
        $FunctionalProvider<
          InMemoryAttachmentOpener,
          InMemoryAttachmentOpener,
          InMemoryAttachmentOpener
        >
    with $Provider<InMemoryAttachmentOpener> {
  /// Ouvreur de pièces jointes simulé. Exposé à part pour que les tests puissent
  /// lire ce qu'on lui a confié, et simuler un appareil qui ne sait pas l'ouvrir.
  InMemoryAttachmentOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inMemoryAttachmentOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inMemoryAttachmentOpenerHash();

  @$internal
  @override
  $ProviderElement<InMemoryAttachmentOpener> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InMemoryAttachmentOpener create(Ref ref) {
    return inMemoryAttachmentOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InMemoryAttachmentOpener value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InMemoryAttachmentOpener>(value),
    );
  }
}

String _$inMemoryAttachmentOpenerHash() =>
    r'89c62f50347694ee47a7f806103e9dc56b07e322';

/// Sélecteur de pièces jointes simulé. Exposé à part pour que les tests
/// puissent lui demander d'annuler la prochaine sélection.

@ProviderFor(inMemoryAttachmentPicker)
final inMemoryAttachmentPickerProvider = InMemoryAttachmentPickerProvider._();

/// Sélecteur de pièces jointes simulé. Exposé à part pour que les tests
/// puissent lui demander d'annuler la prochaine sélection.

final class InMemoryAttachmentPickerProvider
    extends
        $FunctionalProvider<
          InMemoryAttachmentPicker,
          InMemoryAttachmentPicker,
          InMemoryAttachmentPicker
        >
    with $Provider<InMemoryAttachmentPicker> {
  /// Sélecteur de pièces jointes simulé. Exposé à part pour que les tests
  /// puissent lui demander d'annuler la prochaine sélection.
  InMemoryAttachmentPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inMemoryAttachmentPickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inMemoryAttachmentPickerHash();

  @$internal
  @override
  $ProviderElement<InMemoryAttachmentPicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InMemoryAttachmentPicker create(Ref ref) {
    return inMemoryAttachmentPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InMemoryAttachmentPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InMemoryAttachmentPicker>(value),
    );
  }
}

String _$inMemoryAttachmentPickerHash() =>
    r'57759d6437a4b3e4f1538d4f1583d9a69883bb30';

/// Enregistreur simulé. Exposé à part pour la même raison que le sélecteur :
/// c'est par lui qu'un test simule un micro refusé.

@ProviderFor(inMemoryAudioRecorder)
final inMemoryAudioRecorderProvider = InMemoryAudioRecorderProvider._();

/// Enregistreur simulé. Exposé à part pour la même raison que le sélecteur :
/// c'est par lui qu'un test simule un micro refusé.

final class InMemoryAudioRecorderProvider
    extends
        $FunctionalProvider<
          InMemoryAudioRecorderService,
          InMemoryAudioRecorderService,
          InMemoryAudioRecorderService
        >
    with $Provider<InMemoryAudioRecorderService> {
  /// Enregistreur simulé. Exposé à part pour la même raison que le sélecteur :
  /// c'est par lui qu'un test simule un micro refusé.
  InMemoryAudioRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inMemoryAudioRecorderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inMemoryAudioRecorderHash();

  @$internal
  @override
  $ProviderElement<InMemoryAudioRecorderService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InMemoryAudioRecorderService create(Ref ref) {
    return inMemoryAudioRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InMemoryAudioRecorderService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InMemoryAudioRecorderService>(value),
    );
  }
}

String _$inMemoryAudioRecorderHash() =>
    r'a4c80bbf10fe006c6597245de22739d28a9115a6';

/// Source des changements du stock. La doublure InMemory *est* sa propre
/// source : elle émet quand on la modifie.

@ProviderFor(smsEventSource)
final smsEventSourceProvider = SmsEventSourceProvider._();

/// Source des changements du stock. La doublure InMemory *est* sa propre
/// source : elle émet quand on la modifie.

final class SmsEventSourceProvider
    extends $FunctionalProvider<SmsEventSource, SmsEventSource, SmsEventSource>
    with $Provider<SmsEventSource> {
  /// Source des changements du stock. La doublure InMemory *est* sa propre
  /// source : elle émet quand on la modifie.
  SmsEventSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smsEventSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smsEventSourceHash();

  @$internal
  @override
  $ProviderElement<SmsEventSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SmsEventSource create(Ref ref) {
    return smsEventSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmsEventSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmsEventSource>(value),
    );
  }
}

String _$smsEventSourceHash() => r'4ce0c14515abfdd9737f03eec275d5a5484b9e25';

/// Flux des événements du stock, tel que le consomment les vues.
///
/// Les providers de données le `watch`ent sans jamais lire sa valeur : chaque
/// émission suffit à les faire se recharger. C'est ce qui fait apparaître un
/// SMS reçu sans que l'utilisateur ait à tirer sur la liste.

@ProviderFor(smsEvents)
final smsEventsProvider = SmsEventsProvider._();

/// Flux des événements du stock, tel que le consomment les vues.
///
/// Les providers de données le `watch`ent sans jamais lire sa valeur : chaque
/// émission suffit à les faire se recharger. C'est ce qui fait apparaître un
/// SMS reçu sans que l'utilisateur ait à tirer sur la liste.

final class SmsEventsProvider
    extends
        $FunctionalProvider<AsyncValue<SmsEvent>, SmsEvent, Stream<SmsEvent>>
    with $FutureModifier<SmsEvent>, $StreamProvider<SmsEvent> {
  /// Flux des événements du stock, tel que le consomment les vues.
  ///
  /// Les providers de données le `watch`ent sans jamais lire sa valeur : chaque
  /// émission suffit à les faire se recharger. C'est ce qui fait apparaître un
  /// SMS reçu sans que l'utilisateur ait à tirer sur la liste.
  SmsEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smsEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smsEventsHash();

  @$internal
  @override
  $StreamProviderElement<SmsEvent> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SmsEvent> create(Ref ref) {
    return smsEvents(ref);
  }
}

String _$smsEventsHash() => r'f3bfd65bc4ed0756f90d16321d6ee73baa8f9484';

/// Demandes de rédaction venues de l'extérieur (notification, lien `sms:`,
/// partage d'une autre app).

@ProviderFor(composeRequestSource)
final composeRequestSourceProvider = ComposeRequestSourceProvider._();

/// Demandes de rédaction venues de l'extérieur (notification, lien `sms:`,
/// partage d'une autre app).

final class ComposeRequestSourceProvider
    extends
        $FunctionalProvider<
          ComposeRequestSource,
          ComposeRequestSource,
          ComposeRequestSource
        >
    with $Provider<ComposeRequestSource> {
  /// Demandes de rédaction venues de l'extérieur (notification, lien `sms:`,
  /// partage d'une autre app).
  ComposeRequestSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'composeRequestSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$composeRequestSourceHash();

  @$internal
  @override
  $ProviderElement<ComposeRequestSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ComposeRequestSource create(Ref ref) {
    return composeRequestSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComposeRequestSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComposeRequestSource>(value),
    );
  }
}

String _$composeRequestSourceHash() =>
    r'04799536f37814ac2dd5ace592ca3dbdbfe74ed9';

/// Flux de ces demandes, écouté par `MessagesApp` pour ouvrir le bon fil.

@ProviderFor(composeRequests)
final composeRequestsProvider = ComposeRequestsProvider._();

/// Flux de ces demandes, écouté par `MessagesApp` pour ouvrir le bon fil.

final class ComposeRequestsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComposeRequest>,
          ComposeRequest,
          Stream<ComposeRequest>
        >
    with $FutureModifier<ComposeRequest>, $StreamProvider<ComposeRequest> {
  /// Flux de ces demandes, écouté par `MessagesApp` pour ouvrir le bon fil.
  ComposeRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'composeRequestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$composeRequestsHash();

  @$internal
  @override
  $StreamProviderElement<ComposeRequest> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ComposeRequest> create(Ref ref) {
    return composeRequests(ref);
  }
}

String _$composeRequestsHash() => r'956dc71fb863ed951fc86a1a791594d8597d91fa';
