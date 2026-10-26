import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/state.dart';
import '../screens/chat_view.dart';
import '../screens/stats_view.dart';

bool isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < 760;

Future<void> openChannel(BuildContext context, AppState state, String serverId,
    Channel channel) async {
  final server = state.serverById(serverId);
  final target = Target.channelView(
    serverId: serverId,
    serverName: server?.name ?? 'Server',
    channelId: channel.id,
    title: channel.name,
    topic: channel.topic,
    channelType: channel.type,
    icon: channel.icon,
    iconColor: channel.iconColor,
  );
  final narrow = isNarrow(context);
  if (channel.isStats) {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => StatsPage(serverId: serverId, channel: channel),
    ));
    return;
  }
  if (channel.isVoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Voice rooms are not available in this client yet.')),
    );
    return;
  }
  unawaited(state.selectChannel(serverId, channel));
  if (narrow) {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ChatPage(target: target),
    ));
  }
}

Future<void> openConversation(
    BuildContext context, AppState state, Conversation conversation) async {
  final target = Target.conversation(
    conversation.id,
    title: conversation.titleFor(state.me?.id ?? ''),
  );
  final narrow = isNarrow(context);
  unawaited(state.openConversation(conversation));
  if (narrow) {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ChatPage(target: target),
    ));
  }
}
