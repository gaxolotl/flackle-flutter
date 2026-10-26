import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;

import '../screens/chat_view.dart';
import 'api.dart';
import 'models.dart';
import 'notification_isolate.dart';
import 'state.dart';

/// Android notifications for mentions, replies and direct messages, with
/// "Mark as read" and inline "Reply" actions.
class AppNotifications {
  AppNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static AppState? _state;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static String? _pendingPayload;
  static bool _ready = false;

  static Future<void> bind({
    required AppState state,
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _state = state;
    _navigatorKey = navigatorKey;
    state.onNotify = showMessage;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await ensurePlugin();

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      if (payload != null) {
        _pendingPayload = payload;
        flushPending();
      }
    }
  }

  /// Initializes the notification plugin in any isolate (UI or background
  /// service). Safe to call repeatedly.
  static Future<void> ensurePlugin() async {
    if (!_ready) {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_flackle'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _mainResponse,
        onDidReceiveBackgroundNotificationResponse:
            notificationActionBackground,
      );
      _ready = true;
    }
  }

  static void flushPending() {
    final payload = _pendingPayload;
    if (payload == null || _state?.me == null) return;
    _pendingPayload = null;
    unawaited(_openPayload(payload));
  }

  static Future<void> showMessage(
    Message message,
    Target target,
    String title,
    String body,
  ) async {
    if (!_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final payload = jsonEncode({
      ...target.toJson(),
      'message_id': message.id,
      'title': target.title,
      'server_name': target.serverName,
      'channel_type': target.channelType,
      'icon': target.icon,
      'icon_color': target.iconColor,
    });
    final details = AndroidNotificationDetails(
      'flackle_mentions',
      'Mentions & replies',
      channelDescription: 'Mentions, replies and direct messages',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_read',
          'Mark as read',
          semanticAction: SemanticAction.markAsRead,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'reply',
          'Reply',
          inputs: const <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'Reply'),
          ],
          semanticAction: SemanticAction.reply,
          cancelNotification: true,
        ),
      ],
    );
    final id = message.id.hashCode & 0x7fffffff;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
        payload: payload,
      );
    } catch (_) {
      // Notifications are best-effort; the in-app list still records them.
    }
  }

  static Future<void> _mainResponse(NotificationResponse response) async {
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      await _openPayload(response.payload);
      return;
    }
    if (response.actionId == 'mark_read' || response.actionId == 'reply') {
      await _performAction(
        response.payload,
        response.actionId,
        response.input,
        live: true,
      );
    }
  }

  static Future<void> _openPayload(String? raw) async {
    if (raw == null || raw.isEmpty) return;
    final state = _state;
    if (state == null || state.me == null) {
      _pendingPayload = raw;
      return;
    }
    final payload = asMap(jsonDecode(raw));
    final target = _targetFromPayload(payload);

    if (target.isChannel) {
      final serverId = target.serverId!;
      final channelId = target.channelId!;
      var channel = state.channelById(serverId, channelId);
      if (channel == null) {
        await state.loadBundle(serverId);
        channel = state.channelById(serverId, channelId);
      }
      if (channel != null) {
        await state.selectChannel(serverId, channel);
      }
    } else if (target.conversationId != null) {
      var conversation = state.conversations
          .where((entry) => entry.id == target.conversationId)
          .firstOrNull;
      if (conversation == null) {
        await state.refreshConversations();
        conversation = state.conversations
            .where((entry) => entry.id == target.conversationId)
            .firstOrNull;
      }
      if (conversation != null) {
        await state.openConversation(conversation);
      }
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retry = _navigatorKey?.currentState;
        retry?.push<void>(MaterialPageRoute(
          builder: (_) => ChatPage(target: target),
        ));
      });
      return;
    }
    await navigator.push<void>(MaterialPageRoute(
      builder: (_) => ChatPage(target: target),
    ));
  }

  static Future<void> _performAction(
    String? raw,
    String? actionId,
    String? input, {
    bool live = false,
  }) async {
    if (raw == null || raw.isEmpty) return;
    final payload = asMap(jsonDecode(raw));
    final target = _targetFromPayload(payload);
    final messageId = asString(payload['message_id']);

    FlackleClient? client;
    var owned = false;
    if (live) {
      client = _state?.client;
    }
    if (client == null) {
      client = FlackleClient();
      owned = true;
      final user = await client.restoreSession();
      if (user == null) {
        await client.dispose();
        return;
      }
      await client.connect(const []);
      if (!await client.waitForConnection(const Duration(seconds: 10))) {
        await client.dispose();
        return;
      }
    }

    try {
      if (actionId == 'mark_read') {
        if (!client.isConnected) {
          await client.waitForConnection(const Duration(seconds: 8));
        }
        await client.markRead(target, messageId);
        if (owned) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        } else if (_state != null) {
          if (target.isChannel && target.channelId != null) {
            _state!.unread.remove(target.channelId);
          }
          _state!.notifyListeners();
        }
      } else if (actionId == 'reply' &&
          input != null &&
          input.trim().isNotEmpty) {
        await client.sendMessage(target, input.trim());
      }
    } catch (_) {
      // The notification has already been dismissed; the app will refresh.
    } finally {
      if (owned) {
        await client.disconnect();
        await client.dispose();
      }
    }
  }

  static Target _targetFromPayload(Map<String, dynamic> payload) {
    final serverId = asStringOrNull(payload['server_id']);
    final channelId = asStringOrNull(payload['channel_id']);
    if (serverId != null && channelId != null) {
      return Target.channelView(
        serverId: serverId,
        serverName: asString(payload['server_name'], 'Server'),
        channelId: channelId,
        title: asString(payload['title'], 'channel'),
        channelType: asString(payload['channel_type'], 'text'),
        icon: asStringOrNull(payload['icon']),
        iconColor: asStringOrNull(payload['icon_color']),
      );
    }
    return Target.conversation(
      asString(payload['conversation_id']),
      title: asStringOrNull(payload['title']) ?? 'Direct message',
    );
  }
}

/// Runs in the plugin's background isolate for notification actions.
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) {
  ensureNotificationIsolateReady();
  final actionId = response.actionId;
  if (actionId != 'mark_read' && actionId != 'reply') return;
  unawaited(AppNotifications._performAction(
    response.payload,
    actionId,
    response.input,
  ));
}
