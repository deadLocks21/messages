import 'package:messages/core/application/services/logger_application.service.dart';
import 'dart:convert';

import 'package:messages/core/domain/model/conversation_preference.dart';
import 'package:messages/core/domain/services/conversation_preferences.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages de fil persistés dans `shared_preferences`, sous une seule clé
/// JSON : le volume est minuscule (quelques fils épinglés ou archivés) et une
/// écriture atomique évite d'avoir à réconcilier des clés éparpillées.
///
/// Forme stockée :
/// ```json
/// {"42": {"pinned": true, "archived": false, "muted": false}}
/// ```
class SharedPreferencesConversationPreferencesRepository
    implements ConversationPreferencesRepository {
  static const _key = 'messages.conversation_preferences';

  final LoggerApplicationService _logger;

  const SharedPreferencesConversationPreferencesRepository({
    required LoggerApplicationService logger,
  }) : _logger = logger;

  @override
  Future<List<ConversationPreference>> listAll() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return _decode(raw).values.toList();
  }

  @override
  Future<void> save(ConversationPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(_key));
    all[preference.threadId] = preference;
    await prefs.setString(_key, _encode(all));
  }

  @override
  Future<void> remove(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(_key));
    if (all.remove(threadId) == null) return;
    await prefs.setString(_key, _encode(all));
  }

  /// Une valeur illisible (format d'une version antérieure, écriture
  /// interrompue) est traitée comme « aucun réglage » : perdre un épinglage
  /// vaut mieux que bloquer la liste des conversations.
  Map<String, ConversationPreference> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (threadId, value) => MapEntry(
          threadId,
          ConversationPreference(
            threadId: threadId,
            pinned: (value as Map<String, dynamic>)['pinned'] == true,
            archived: value['archived'] == true,
            muted: value['muted'] == true,
          ),
        ),
      );
    } catch (e, stack) {
      // Un blob illisible fait disparaître d'un coup tous les épinglages,
      // archivages et sourdines. L'app repart de zéro sans rien dire ; c'est
      // exactement le genre de perte qu'on ne comprend qu'en la voyant dans
      // les logs.
      _logger.error(
        'preferences.decode_failed',
        attrs: {'preferences.key': _key},
        error: e,
        stack: stack,
      );
      return {};
    }
  }

  String _encode(Map<String, ConversationPreference> all) => jsonEncode({
    for (final entry in all.entries)
      entry.key: {
        'pinned': entry.value.pinned,
        'archived': entry.value.archived,
        'muted': entry.value.muted,
      },
  });
}
