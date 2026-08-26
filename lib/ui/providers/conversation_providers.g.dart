// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Vues de données de l'app. Toutes `watch`ent [smsEventsProvider] sans lire sa
/// valeur : c'est ce qui les fait se recharger dès que le stock bouge (SMS
/// reçu, accusé de remise, suppression depuis une autre app).
///
/// Les écrans affichent le rechargement avec `skipLoadingOnReload: true` pour
/// que la liste ne clignote pas à chaque événement.

@ProviderFor(conversations)
final conversationsProvider = ConversationsFamily._();

/// Vues de données de l'app. Toutes `watch`ent [smsEventsProvider] sans lire sa
/// valeur : c'est ce qui les fait se recharger dès que le stock bouge (SMS
/// reçu, accusé de remise, suppression depuis une autre app).
///
/// Les écrans affichent le rechargement avec `skipLoadingOnReload: true` pour
/// que la liste ne clignote pas à chaque événement.

final class ConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ConversationDto>>,
          List<ConversationDto>,
          FutureOr<List<ConversationDto>>
        >
    with
        $FutureModifier<List<ConversationDto>>,
        $FutureProvider<List<ConversationDto>> {
  /// Vues de données de l'app. Toutes `watch`ent [smsEventsProvider] sans lire sa
  /// valeur : c'est ce qui les fait se recharger dès que le stock bouge (SMS
  /// reçu, accusé de remise, suppression depuis une autre app).
  ///
  /// Les écrans affichent le rechargement avec `skipLoadingOnReload: true` pour
  /// que la liste ne clignote pas à chaque événement.
  ConversationsProvider._({
    required ConversationsFamily super.from,
    required ConversationFilter super.argument,
  }) : super(
         retry: null,
         name: r'conversationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationsHash();

  @override
  String toString() {
    return r'conversationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ConversationDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ConversationDto>> create(Ref ref) {
    final argument = this.argument as ConversationFilter;
    return conversations(ref, filter: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationsHash() => r'43439099d9e1ef493e483ccbf560687f547d2b87';

/// Vues de données de l'app. Toutes `watch`ent [smsEventsProvider] sans lire sa
/// valeur : c'est ce qui les fait se recharger dès que le stock bouge (SMS
/// reçu, accusé de remise, suppression depuis une autre app).
///
/// Les écrans affichent le rechargement avec `skipLoadingOnReload: true` pour
/// que la liste ne clignote pas à chaque événement.

final class ConversationsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ConversationDto>>,
          ConversationFilter
        > {
  ConversationsFamily._()
    : super(
        retry: null,
        name: r'conversationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Vues de données de l'app. Toutes `watch`ent [smsEventsProvider] sans lire sa
  /// valeur : c'est ce qui les fait se recharger dès que le stock bouge (SMS
  /// reçu, accusé de remise, suppression depuis une autre app).
  ///
  /// Les écrans affichent le rechargement avec `skipLoadingOnReload: true` pour
  /// que la liste ne clignote pas à chaque événement.

  ConversationsProvider call({
    ConversationFilter filter = ConversationFilter.all,
  }) => ConversationsProvider._(argument: filter, from: this);

  @override
  String toString() => r'conversationsProvider';
}

@ProviderFor(conversation)
final conversationProvider = ConversationFamily._();

final class ConversationProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConversationDto?>,
          ConversationDto?,
          FutureOr<ConversationDto?>
        >
    with $FutureModifier<ConversationDto?>, $FutureProvider<ConversationDto?> {
  ConversationProvider._({
    required ConversationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationHash();

  @override
  String toString() {
    return r'conversationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ConversationDto?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConversationDto?> create(Ref ref) {
    final argument = this.argument as String;
    return conversation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationHash() => r'ff05433b06ed61e9258f1dfb8291e676f54e6dc2';

final class ConversationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ConversationDto?>, String> {
  ConversationFamily._()
    : super(
        retry: null,
        name: r'conversationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationProvider call(String threadId) =>
      ConversationProvider._(argument: threadId, from: this);

  @override
  String toString() => r'conversationProvider';
}

@ProviderFor(conversationTimeline)
final conversationTimelineProvider = ConversationTimelineFamily._();

final class ConversationTimelineProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConversationTimelineDto>,
          ConversationTimelineDto,
          FutureOr<ConversationTimelineDto>
        >
    with
        $FutureModifier<ConversationTimelineDto>,
        $FutureProvider<ConversationTimelineDto> {
  ConversationTimelineProvider._({
    required ConversationTimelineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationTimelineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationTimelineHash();

  @override
  String toString() {
    return r'conversationTimelineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ConversationTimelineDto> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ConversationTimelineDto> create(Ref ref) {
    final argument = this.argument as String;
    return conversationTimeline(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationTimelineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationTimelineHash() =>
    r'c520f16d8b001ddb5f805d4aff58622356c4453c';

final class ConversationTimelineFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ConversationTimelineDto>, String> {
  ConversationTimelineFamily._()
    : super(
        retry: null,
        name: r'conversationTimelineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConversationTimelineProvider call(String threadId) =>
      ConversationTimelineProvider._(argument: threadId, from: this);

  @override
  String toString() => r'conversationTimelineProvider';
}

/// Nombre de fils non lus — pastille de la puce « Non lus ».
///
/// Dérivé de la liste déjà construite, jamais recalculé : la reconstruire pour
/// n'en tirer qu'un entier coûtait un second parcours complet du stock et une
/// seconde lecture du carnet d'adresses, à chaque démarrage et à chaque
/// changement. Le filtre « non lues » est exactement « non archivé et non lu »,
/// donc compter sur la liste « tous » donne le même nombre.

@ProviderFor(unreadConversationCount)
final unreadConversationCountProvider = UnreadConversationCountProvider._();

/// Nombre de fils non lus — pastille de la puce « Non lus ».
///
/// Dérivé de la liste déjà construite, jamais recalculé : la reconstruire pour
/// n'en tirer qu'un entier coûtait un second parcours complet du stock et une
/// seconde lecture du carnet d'adresses, à chaque démarrage et à chaque
/// changement. Le filtre « non lues » est exactement « non archivé et non lu »,
/// donc compter sur la liste « tous » donne le même nombre.

final class UnreadConversationCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Nombre de fils non lus — pastille de la puce « Non lus ».
  ///
  /// Dérivé de la liste déjà construite, jamais recalculé : la reconstruire pour
  /// n'en tirer qu'un entier coûtait un second parcours complet du stock et une
  /// seconde lecture du carnet d'adresses, à chaque démarrage et à chaque
  /// changement. Le filtre « non lues » est exactement « non archivé et non lu »,
  /// donc compter sur la liste « tous » donne le même nombre.
  UnreadConversationCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadConversationCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadConversationCountHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return unreadConversationCount(ref);
  }
}

String _$unreadConversationCountHash() =>
    r'f7651883404d59ea80c885eb376962435a8eb465';

/// Contacts proposés par le sélecteur de destinataires, filtrés par la saisie.

@ProviderFor(contactSuggestions)
final contactSuggestionsProvider = ContactSuggestionsFamily._();

/// Contacts proposés par le sélecteur de destinataires, filtrés par la saisie.

final class ContactSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContactDto>>,
          List<ContactDto>,
          FutureOr<List<ContactDto>>
        >
    with $FutureModifier<List<ContactDto>>, $FutureProvider<List<ContactDto>> {
  /// Contacts proposés par le sélecteur de destinataires, filtrés par la saisie.
  ContactSuggestionsProvider._({
    required ContactSuggestionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contactSuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contactSuggestionsHash();

  @override
  String toString() {
    return r'contactSuggestionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContactDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContactDto>> create(Ref ref) {
    final argument = this.argument as String;
    return contactSuggestions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContactSuggestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contactSuggestionsHash() =>
    r'e4ed48117d71287f790a19a6d34cb93d86f3fd25';

/// Contacts proposés par le sélecteur de destinataires, filtrés par la saisie.

final class ContactSuggestionsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ContactDto>>, String> {
  ContactSuggestionsFamily._()
    : super(
        retry: null,
        name: r'contactSuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Contacts proposés par le sélecteur de destinataires, filtrés par la saisie.

  ContactSuggestionsProvider call(String query) =>
      ContactSuggestionsProvider._(argument: query, from: this);

  @override
  String toString() => r'contactSuggestionsProvider';
}

/// Brouillon persisté d'un fil, pour amorcer le champ de rédaction.

@ProviderFor(draft)
final draftProvider = DraftFamily._();

/// Brouillon persisté d'un fil, pour amorcer le champ de rédaction.

final class DraftProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Brouillon persisté d'un fil, pour amorcer le champ de rédaction.
  DraftProvider._({
    required DraftFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'draftProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$draftHash();

  @override
  String toString() {
    return r'draftProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return draft(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DraftProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$draftHash() => r'be27ef3a23e36739da0769e0821e8d4cb4339c2d';

/// Brouillon persisté d'un fil, pour amorcer le champ de rédaction.

final class DraftFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  DraftFamily._()
    : super(
        retry: null,
        name: r'draftProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Brouillon persisté d'un fil, pour amorcer le champ de rédaction.

  DraftProvider call(String threadId) =>
      DraftProvider._(argument: threadId, from: this);

  @override
  String toString() => r'draftProvider';
}
