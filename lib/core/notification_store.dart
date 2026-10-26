import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persists notification history so the You tab is populated after a restart.
class NotificationStore {
  NotificationStore._();

  static const _key = 'flackle.mobile.notifications.v1';
  static const _limit = 80;

  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map(asMap).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add({
    required String title,
    required String body,
    Target? target,
    DateTime? createdAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await load();
      entries.insert(0, {
        'title': title,
        'body': body,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        if (target != null)
          'target': {
            ...target.toJson(),
            'title': target.title,
            'server_name': target.serverName,
            'channel_type': target.channelType,
            'icon': target.icon,
            'icon_color': target.iconColor,
          },
      });
      if (entries.length > _limit) entries.removeRange(_limit, entries.length);
      await prefs.setString(_key, jsonEncode(entries));
    } catch (_) {
      // Notification history is best-effort.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
