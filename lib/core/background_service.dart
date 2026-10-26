import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'notification_store.dart';
import 'notifications.dart';

const _uiActiveKey = 'flackle.ui_active';
const _serviceId = 4401;

Future<void> initFlackleBackgroundService() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'flackle_background',
      channelName: 'Flackle background connection',
      channelDescription:
          'Keeps Flackle connected so mentions arrive while the app is closed.',
      channelImportance: NotificationChannelImportance.MIN,
      priority: NotificationPriority.MIN,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(60000),
      allowWakeLock: true,
      allowWifiLock: true,
      allowAutoRestart: true,
      stopWithTask: false,
    ),
  );
}

Future<void> startFlackleBackgroundService() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.remoteMessaging],
      notificationTitle: 'Flackle is listening',
      notificationText: 'Mentions and replies will notify you',
      notificationIcon: const NotificationIcon(
        metaDataName: 'dev.flackle.mobile.service_icon',
      ),
      callback: flackleForegroundCallback,
    );
  } catch (_) {
    // The app still receives notifications while it is alive.
  }
}

Future<void> stopFlackleBackgroundService() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  } catch (_) {}
}

Future<void> setFlackleUiActive(bool active) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_uiActiveKey, active);
  } catch (_) {}
}

@pragma('vm:entry-point')
void flackleForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_FlackleTaskHandler());
}

class _FlackleTaskHandler extends TaskHandler {
  FlackleClient? _client;
  StreamSubscription<GatewayEvent>? _events;
  SelfUser? _me;
  List<Server> _servers = const [];
  List<Conversation> _conversations = const [];
  final Map<String, ChannelBundle> _bundles = {};
  final Set<String> _seen = {};
  bool _connecting = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _connect();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_client == null) {
      unawaited(_connect());
    } else if (!_client!.isConnected) {
      unawaited(_client!
          .connect(_servers.map((s) => s.id).toList())
          .catchError((Object _) {}));
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _events?.cancel();
    await _client?.disconnect();
    await _client?.dispose();
    _client = null;
  }

  Future<void> _connect() async {
    if (_connecting) return;
    _connecting = true;
    final client = FlackleClient();
    try {
      final user = await client.restoreSession();
      if (user == null) {
        await client.dispose();
        return;
      }
      final data = await client.bootstrap();
      _me = user;
      _servers = data['servers'] as List<Server>;
      _conversations = data['conversations'] as List<Conversation>;
      _events = client.events.listen(_onEvent);
      await client.connect(_servers.map((server) => server.id).toList());
      await client.waitForConnection(const Duration(seconds: 12));
      _client = client;
      await FlutterForegroundTask.updateService(
        notificationText: 'Listening for mentions as ${user.name}',
      );
    } catch (_) {
      await client.dispose();
    } finally {
      _connecting = false;
    }
  }

  Future<void> _onEvent(GatewayEvent event) async {
    if (event.type != 'channel_message' && event.type != 'new_message') {
      return;
    }
    final payload = event.payload;
    final raw = payload['message'] is Map ? asMap(payload['message']) : payload;
    final message = Message.fromJson(raw);
    if (message.id.isEmpty || _seen.contains(message.id)) return;
    _seen.add(message.id);
    if (_seen.length > 300) _seen.remove(_seen.first);

    final author = message.sender;
    if (author == null || author.id == _me?.id) return;
    final mentioned = message.mentionEveryone ||
        (_me != null && message.mentionIds.contains(_me!.id));
    final replied = message.replyTo?.senderId == _me?.id;
    final conversationId =
        event.conversationId ?? asStringOrNull(raw['conversation_id']);
    if (conversationId == null && !mentioned && !replied) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_uiActiveKey) ?? false) return;

    final serverId = event.serverId ?? asStringOrNull(raw['server_id']);
    final channelId = event.channelId ?? asStringOrNull(raw['channel_id']);
    final target = await _targetFor(
      serverId: serverId,
      channelId: channelId,
      conversationId: conversationId,
      author: author,
    );
    if (target == null) return;

    final body =
        message.content.isEmpty ? 'Sent an attachment' : message.content;
    final String title;
    if (mentioned) {
      title = '${author.name} mentioned you';
    } else if (replied) {
      title = '${author.name} replied to you';
    } else {
      title = author.name;
    }
    await AppNotifications.ensurePlugin();
    await AppNotifications.showMessage(message, target, title, body);
    await NotificationStore.add(
      title: title,
      body: body,
      target: target,
      createdAt: message.createdAt,
    );
  }

  Future<Target?> _targetFor({
    required String? serverId,
    required String? channelId,
    required String? conversationId,
    required User author,
  }) async {
    if (conversationId != null) {
      final conversation = _conversations
          .firstWhereOrNull((entry) => entry.id == conversationId);
      return Target.conversation(
        conversationId,
        title: conversation?.titleFor(_me?.id ?? '') ?? author.name,
      );
    }
    if (serverId == null || channelId == null) return null;
    var bundle = _bundles[serverId];
    if (bundle == null) {
      try {
        bundle = await _client?.fetchChannels(serverId);
        if (bundle != null) _bundles[serverId] = bundle;
      } catch (_) {}
    }
    final channel =
        bundle?.channels.firstWhereOrNull((entry) => entry.id == channelId);
    final server = _servers.firstWhereOrNull((entry) => entry.id == serverId);
    return Target.channelView(
      serverId: serverId,
      serverName: server?.name ?? 'Server',
      channelId: channelId,
      title: channel?.name ?? 'channel',
      channelType: channel?.type ?? 'text',
      icon: channel?.icon,
      iconColor: channel?.iconColor,
    );
  }
}
