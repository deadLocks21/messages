import 'package:messages/core/application/dtos/contact.dto.dart';
import 'package:messages/core/application/dtos/conversation.dto.dart';
import 'package:messages/core/application/dtos/conversation_timeline.dto.dart';
import 'package:messages/core/domain/model/enums.dart';
import 'package:messages/infrastructure/providers/infra_providers.dart';
import 'package:messages/infrastructure/providers/repository_providers.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_providers.g.dart';

/// Vues de données de l'app. Toutes `watch`ent [smsEventsProvider] sans lire sa
/// valeur : c'est ce qui les fait se recharger dès que le stock bouge (SMS
/// reçu, accusé de remise, suppression depuis une autre app).
///
/// Les écrans affichent le rechargement avec `skipLoadingOnReload: true` pour
/// que la liste ne clignote pas à chaque événement.

@riverpod
Future<List<ConversationDto>> conversations(
  Ref ref, {
  ConversationFilter filter = ConversationFilter.all,
}) async {
  ref.watch(smsEventsProvider);
  return ref.watch(conversationListServiceProvider).list(filter: filter);
}

@riverpod
Future<ConversationDto?> conversation(Ref ref, String threadId) async {
  ref.watch(smsEventsProvider);
  return ref.watch(conversationListServiceProvider).byId(threadId);
}

@riverpod
Future<ConversationTimelineDto> conversationTimeline(
  Ref ref,
  String threadId,
) async {
  ref.watch(smsEventsProvider);
  return ref.watch(conversationTimelineServiceProvider).build(threadId);
}

/// Nombre de fils non lus — pastille de la puce « Non lus ».
@riverpod
Future<int> unreadConversationCount(Ref ref) async {
  ref.watch(smsEventsProvider);
  return ref.watch(conversationListServiceProvider).unreadCount();
}

/// Contacts proposés par le sélecteur de destinataires, filtrés par la saisie.
@riverpod
Future<List<ContactDto>> contactSuggestions(Ref ref, String query) =>
    ref.watch(contactPickerServiceProvider).suggestions(query: query);

/// Brouillon persisté d'un fil, pour amorcer le champ de rédaction.
@riverpod
Future<String?> draft(Ref ref, String threadId) =>
    ref.watch(draftRepositoryProvider).get(threadId);
