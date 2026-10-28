import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccentChoice {
  const AccentChoice(this.id, this.label, this.color);

  final String id;
  final String label;
  final Color color;
}

const accentChoices = [
  AccentChoice('ember', 'Ember', Color(0xFFEF5252)),
  AccentChoice('violet', 'Violet', Color(0xFF8B6CE8)),
  AccentChoice('teal', 'Teal', Color(0xFF2FBD9F)),
  AccentChoice('blue', 'Blue', Color(0xFF4A9BE8)),
  AccentChoice('gold', 'Gold', Color(0xFFE0A13D)),
];

enum Density { cozy, compact }

enum TextSize { small, normal, large }

class AppPrefs extends ChangeNotifier {
  AppPrefs._(this._store, this._values, this._drafts);

  static const _key = 'flackle.mobile.preferences.v1';
  static const _draftsKey = 'flackle.mobile.drafts.v1';

  final SharedPreferences _store;
  Map<String, dynamic> _values;
  final Map<String, String> _drafts;

  static Future<AppPrefs> load() async {
    final store = await SharedPreferences.getInstance();
    Map<String, dynamic> values = {};
    final raw = store.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map)
          values = decoded.map((key, value) => MapEntry('$key', value));
      } catch (_) {
        values = {};
      }
    }
    final drafts = <String, String>{};
    final rawDrafts = store.getString(_draftsKey);
    if (rawDrafts != null && rawDrafts.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDrafts);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is String) drafts['${entry.key}'] = entry.value;
          }
        }
      } catch (_) {
        drafts.clear();
      }
    }
    return AppPrefs._(store, {..._defaults, ...values}, drafts);
  }

  String draft(String key) => _drafts[key] ?? '';

  Future<void> setDraft(String key, String value) async {
    if (value.isEmpty) {
      if (_drafts.remove(key) == null) return;
    } else {
      if (_drafts[key] == value) return;
      _drafts[key] = value;
    }
    await _store.setString(_draftsKey, jsonEncode(_drafts));
  }

  Future<void> clearDraft(String key) => setDraft(key, '');

  static const Map<String, dynamic> _defaults = {
    'theme': 'dark',
    'accent': 'ember',
    'density': 'cozy',
    'textSize': 'normal',
    'reduceMotion': false,
    'startWithMembers': true,
    'notifications': true,
    'mentionsOnly': false,
    'timeFormat': '12h',
    'sendKey': 'enter',
    'showTyping': true,
    'shareTyping': true,
    'linkPreviews': true,
    'composeAutoEmbeds': true,
    'characterCounter': true,
    'mentionAvatars': true,
    'quickReactions': true,
    'previewMessage': true,
    'replyPings': 'on',
    'lastReplyMention': true,
    'showMeYourName': true,
    'keepCurrentChannel': true,
    'viewIcons': true,
    'showMediaExpiry': true,
  };

  T _read<T>(String key) => (_values[key] as T?) ?? (_defaults[key] as T);

  Future<void> _write(String key, Object? value) async {
    _values[key] = value;
    notifyListeners();
    await _store.setString(_key, jsonEncode(_values));
  }

  String get theme => _read<String>('theme');
  ThemeMode get themeMode => switch (theme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
  Future<void> setTheme(String value) => _write('theme', value);

  String get accent => _read<String>('accent');
  Color get accentColor => accentChoices
      .firstWhere((choice) => choice.id == accent,
          orElse: () => accentChoices.first)
      .color;
  Future<void> setAccent(String value) => _write('accent', value);

  String get density => _read<String>('density');
  bool get compact => density == 'compact';
  Future<void> setDensity(String value) => _write('density', value);

  String get textSize => _read<String>('textSize');
  double get messageFontSize => switch (textSize) {
        'small' => 13.4,
        'large' => 15.8,
        _ => 14.6,
      };
  Future<void> setTextSize(String value) => _write('textSize', value);

  bool get reduceMotion => _read<bool>('reduceMotion');
  Future<void> setReduceMotion(bool value) => _write('reduceMotion', value);

  bool get startWithMembers => _read<bool>('startWithMembers');
  Future<void> setStartWithMembers(bool value) =>
      _write('startWithMembers', value);

  bool get notifications => _read<bool>('notifications');
  Future<void> setNotifications(bool value) => _write('notifications', value);

  bool get mentionsOnly => _read<bool>('mentionsOnly');
  Future<void> setMentionsOnly(bool value) => _write('mentionsOnly', value);

  bool get use24h => _read<String>('timeFormat') == '24h';
  Future<void> setTimeFormat(String value) => _write('timeFormat', value);

  bool get sendOnEnter => _read<String>('sendKey') == 'enter';
  Future<void> setSendKey(String value) => _write('sendKey', value);

  bool get showTyping => _read<bool>('showTyping');
  Future<void> setShowTyping(bool value) => _write('showTyping', value);

  bool get shareTyping => _read<bool>('shareTyping');
  Future<void> setShareTyping(bool value) => _write('shareTyping', value);

  bool get linkPreviews => _read<bool>('linkPreviews');
  Future<void> setLinkPreviews(bool value) => _write('linkPreviews', value);

  bool get composeAutoEmbeds => _read<bool>('composeAutoEmbeds');
  Future<void> setComposeAutoEmbeds(bool value) =>
      _write('composeAutoEmbeds', value);

  bool get characterCounter => _read<bool>('characterCounter');
  Future<void> setCharacterCounter(bool value) =>
      _write('characterCounter', value);

  bool get mentionAvatars => _read<bool>('mentionAvatars');
  Future<void> setMentionAvatars(bool value) => _write('mentionAvatars', value);

  bool get quickReactions => _read<bool>('quickReactions');
  Future<void> setQuickReactions(bool value) => _write('quickReactions', value);

  bool get previewMessage => _read<bool>('previewMessage');
  Future<void> setPreviewMessage(bool value) => _write('previewMessage', value);

  /// How a new reply starts: `on`, `remember` or `off`.
  String get replyPings {
    final value = _read<String>('replyPings');
    return value == 'remember' || value == 'off' ? value : 'on';
  }

  bool get lastReplyMention => _read<bool>('lastReplyMention');

  bool get replyMentionDefault => switch (replyPings) {
        'off' => false,
        'remember' => lastReplyMention,
        _ => true,
      };

  Future<void> setReplyPings(String value) {
    final normalized = value == 'remember' || value == 'off' ? value : 'on';
    return _write('replyPings', normalized);
  }

  Future<void> setLastReplyMention(bool value) =>
      _write('lastReplyMention', value);

  bool get showMeYourName => _read<bool>('showMeYourName');
  Future<void> setShowMeYourName(bool value) => _write('showMeYourName', value);

  bool get keepCurrentChannel => _read<bool>('keepCurrentChannel');
  Future<void> setKeepCurrentChannel(bool value) =>
      _write('keepCurrentChannel', value);

  bool get viewIcons => _read<bool>('viewIcons');
  Future<void> setViewIcons(bool value) => _write('viewIcons', value);

  bool get showMediaExpiry => _read<bool>('showMediaExpiry');
  Future<void> setShowMediaExpiry(bool value) =>
      _write('showMediaExpiry', value);

  Future<void> reset() async {
    _values = {..._defaults};
    notifyListeners();
    await _store.setString(_key, jsonEncode(_values));
  }
}
