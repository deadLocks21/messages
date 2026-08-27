import 'package:flutter/foundation.dart';
import 'package:messages/core/domain/model/compose_request.dart';
import 'package:messages/core/domain/model/sms_event.dart';
import 'package:messages/core/domain/services/compose_request.source.dart';
import 'package:messages/core/domain/services/sms_event.source.dart';
import 'package:messages/infrastructure/attachments/in_memory.attachment_picker.service.dart';
import 'package:messages/infrastructure/contacts/in_memory.contact.repository.dart';
import 'package:messages/infrastructure/providers/logger_providers.dart';
import 'package:messages/infrastructure/seed/demo_seed.dart';
import 'package:messages/infrastructure/sms/android.compose_request.source.dart';
import 'package:messages/infrastructure/sms/android.sms_event.source.dart';
import 'package:messages/infrastructure/sms/android_sms.channel.dart';
import 'package:messages/infrastructure/sms/in_memory.compose_request.source.dart';
import 'package:messages/infrastructure/sms/in_memory.sms_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'infra_providers.g.dart';

/// Vrai stock Telephony, ou doublure ?
///
/// Le canal natif n'existe que sur Android. Ailleurs (macOS, web, tests), l'app
/// tourne sur [InMemorySmsStore] pré-rempli par [DemoSeed] : l'UI reste
/// développable et testable sans téléphone.
@Riverpod(keepAlive: true)
bool useNativeSmsStack(Ref ref) =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Pont vers le stock SMS d'Android.
///
/// Le logger lui est passé ici : c'est le canal qui voit passer les échecs de
/// la plateforme, et il est le seul endroit d'où ils soient tous visibles.
@Riverpod(keepAlive: true)
AndroidSmsChannel smsChannel(Ref ref) =>
    AndroidSmsChannel(logger: ref.watch(loggerProvider));

/// Carnet d'adresses simulé, partagé par le seed et le repository InMemory.
@Riverpod(keepAlive: true)
InMemoryContactRepository inMemoryContacts(Ref ref) => InMemoryContactRepository();

/// Stock SMS simulé, monté avec les données de démonstration.
@Riverpod(keepAlive: true)
InMemorySmsStore inMemorySmsStore(Ref ref) {
  final store = InMemorySmsStore(simulateDelivery: true);
  DemoSeed.install(store: store, contacts: ref.watch(inMemoryContactsProvider));
  ref.onDispose(store.dispose);
  return store;
}

/// Sélecteur de pièces jointes simulé. Exposé à part pour que les tests
/// puissent lui demander d'annuler la prochaine sélection.
@Riverpod(keepAlive: true)
InMemoryAttachmentPicker inMemoryAttachmentPicker(Ref ref) =>
    InMemoryAttachmentPicker(ref.watch(inMemorySmsStoreProvider));

/// Source des changements du stock. La doublure InMemory *est* sa propre
/// source : elle émet quand on la modifie.
@Riverpod(keepAlive: true)
SmsEventSource smsEventSource(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidSmsEventSource(ref.watch(smsChannelProvider));
  }
  return ref.watch(inMemorySmsStoreProvider);
}

/// Flux des événements du stock, tel que le consomment les vues.
///
/// Les providers de données le `watch`ent sans jamais lire sa valeur : chaque
/// émission suffit à les faire se recharger. C'est ce qui fait apparaître un
/// SMS reçu sans que l'utilisateur ait à tirer sur la liste.
@Riverpod(keepAlive: true)
Stream<SmsEvent> smsEvents(Ref ref) => ref.watch(smsEventSourceProvider).events;

/// Demandes de rédaction venues de l'extérieur (notification, lien `sms:`,
/// partage d'une autre app).
@Riverpod(keepAlive: true)
ComposeRequestSource composeRequestSource(Ref ref) {
  if (ref.watch(useNativeSmsStackProvider)) {
    return AndroidComposeRequestSource(ref.watch(smsChannelProvider));
  }
  return const InMemoryComposeRequestSource();
}

/// Flux de ces demandes, écouté par `MessagesApp` pour ouvrir le bon fil.
@Riverpod(keepAlive: true)
Stream<ComposeRequest> composeRequests(Ref ref) =>
    ref.watch(composeRequestSourceProvider).requests;
