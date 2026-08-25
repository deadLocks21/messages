import 'package:messages/core/application/dtos/search_results.dto.dart';
import 'package:messages/infrastructure/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.provider.g.dart';

/// Résultats de recherche pour une requête. Auto-dispose : chaque frappe crée
/// une nouvelle instance, les précédentes n'ont pas à survivre.
@riverpod
Future<SearchResultsDto> searchResults(Ref ref, String query) =>
    ref.watch(searchServiceProvider).search(query);
