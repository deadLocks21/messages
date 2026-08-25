import 'dart:convert';

import 'package:messages/core/domain/services/draft.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brouillons persistés dans `shared_preferences`, sous une clé JSON unique
/// (`{"42": "à demain !"}`).
class SharedPreferencesDraftRepository implements DraftRepository {
  static const _key = 'messages.drafts';

  @override
  Future<Map<String, String>> listAll() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return _decode(raw);
  }

  @override
  Future<String?> get(String threadId) async => (await listAll())[threadId];

  @override
  Future<void> save(String threadId, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(_key));
    if (body.trim().isEmpty) {
      if (all.remove(threadId) == null) return;
    } else {
      all[threadId] = body;
    }
    await prefs.setString(_key, jsonEncode(all));
  }

  @override
  Future<void> remove(String threadId) => save(threadId, '');

  Map<String, String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
    } catch (_) {
      return {};
    }
  }
}
