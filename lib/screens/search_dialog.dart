import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/icons.dart';
import '../ui/navigation.dart';
import 'server_channels_page.dart';

Future<void> showQuickSwitcher(BuildContext context,
    {String? serverId, VoidCallback? onNavigate}) async {
  final state = FlackleScope.read(context);
  await showDialog<void>(
    context: context,
    builder: (_) => _QuickSwitcher(
        state: state,
        serverId: serverId,
        parentContext: context,
        onNavigate: onNavigate),
  );
}

class _QuickSwitcher extends StatefulWidget {
  const _QuickSwitcher(
      {required this.state,
      required this.parentContext,
      this.serverId,
      this.onNavigate});

  final AppState state;
  final String? serverId;
  final BuildContext parentContext;
  final VoidCallback? onNavigate;

  @override
  State<_QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends State<_QuickSwitcher> {
  final _query = TextEditingController();
  String _term = '';
  VoidCallback? _firstAction;

  Future<void> _open(Future<void> Function(BuildContext) action) async {
    final parent = widget.parentContext;
    Navigator.of(context).pop();
    try {
      if (!parent.mounted) return;
      await action(parent);
      if (parent.mounted) widget.onNavigate?.call();
    } catch (failure) {
      if (parent.mounted) showAppToast(parent, failure.toString());
    }
  }

  void _clear() {
    _query.clear();
    setState(() => _term = '');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String value) =>
      _term.isEmpty || value.toLowerCase().contains(_term.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final channels = <MapEntry<String, Channel>>[];
    final serverIds = widget.serverId != null
        ? [widget.serverId!]
        : state.servers.map((server) => server.id).toList();
    for (final id in serverIds) {
      for (final channel in state.channelsFor(id)) {
        if (!channel.isText && !channel.isStats) continue;
        channels.add(MapEntry(id, channel));
      }
    }
    final visibleChannels =
        channels.where((entry) => _matches(entry.value.name)).take(8).toList();
    final servers =
        state.servers.where((server) => _matches(server.name)).take(5).toList();
    final conversations = state.conversations
        .where((entry) => _matches(entry.titleFor(state.me?.id ?? '')))
        .take(5)
        .toList();
    final friends = state.friends
        .where((user) => _matches(user.name) || _matches(user.username))
        .take(4)
        .toList();
    final hasResults = visibleChannels.isNotEmpty ||
        servers.isNotEmpty ||
        conversations.isNotEmpty ||
        friends.isNotEmpty;
    if (visibleChannels.isNotEmpty) {
      final entry = visibleChannels.first;
      _firstAction = () => unawaited(_open(
          (parent) => openChannel(parent, state, entry.key, entry.value)));
    } else if (servers.isNotEmpty) {
      _firstAction = () => unawaited(_open((parent) async {
            await state.selectServer(servers.first.id);
            widget.onNavigate?.call();
            if (parent.mounted && isNarrow(parent)) {
              await Navigator.of(parent).push<void>(MaterialPageRoute(
                  builder: (_) =>
                      ServerChannelsPage(serverId: servers.first.id)));
            }
          }));
    } else if (conversations.isNotEmpty) {
      _firstAction = () => unawaited(_open(
          (parent) => openConversation(parent, state, conversations.first)));
    } else if (friends.isNotEmpty) {
      _firstAction = () => unawaited(_open((parent) async {
            final conversation = await state.client.createDM(friends.first.id);
            if (parent.mounted) {
              await openConversation(parent, state, conversation);
            }
          }));
    } else {
      _firstAction = null;
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      onChanged: (value) =>
                          setState(() => _term = value.trim()),
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) {
                        setState(() {});
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _firstAction?.call();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Jump to a server, channel or person',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _query.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: _clear,
                                icon:
                                    const Icon(Icons.close_rounded, size: 18)),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close search',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Flexible(
              child: hasResults
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
                      children: [
                        if (visibleChannels.isNotEmpty)
                          const SectionLabel('Channels'),
                        for (final entry in visibleChannels)
                          _row(
                            context,
                            icon:
                                entry.value.type == 'stats' ? 'chart' : 'hash',
                            title: '#${entry.value.name}',
                            subtitle:
                                state.serverById(entry.key)?.name ?? 'Server',
                            onTap: () => unawaited(_open((parent) =>
                                openChannel(
                                    parent, state, entry.key, entry.value))),
                          ),
                        if (servers.isNotEmpty) const SectionLabel('Servers'),
                        for (final server in servers)
                          _row(
                            context,
                            avatar: AppAvatar(
                              url: server.iconUrl,
                              name: server.name,
                              size: 24,
                              square: true,
                            ),
                            title: server.name,
                            subtitle: server.memberCount == null
                                ? 'Server'
                                : '${server.memberCount} members',
                            onTap: () => unawaited(_open((parent) async {
                              await state.selectServer(server.id);
                              if (parent.mounted) widget.onNavigate?.call();
                              if (parent.mounted && isNarrow(parent)) {
                                await Navigator.of(parent).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ServerChannelsPage(serverId: server.id),
                                  ),
                                );
                              }
                            })),
                          ),
                        if (conversations.isNotEmpty)
                          const SectionLabel('Direct messages'),
                        for (final conversation in conversations)
                          _row(
                            context,
                            avatar: AppAvatar(
                              url: conversation
                                  .otherUser(state.me?.id ?? '')
                                  ?.avatarUrl,
                              name: conversation.titleFor(state.me?.id ?? ''),
                              size: 24,
                            ),
                            title: conversation.titleFor(state.me?.id ?? ''),
                            subtitle: 'Direct message',
                            onTap: () => unawaited(_open((parent) =>
                                openConversation(parent, state, conversation))),
                          ),
                        if (friends.isNotEmpty) const SectionLabel('People'),
                        for (final friend in friends)
                          _row(
                            context,
                            avatar: AppAvatar(
                                url: friend.avatarUrl,
                                name: friend.name,
                                size: 24),
                            title: friend.name,
                            subtitle: friend.handle,
                            onTap: () => unawaited(_open((parent) async {
                              final conversation =
                                  await state.client.createDM(friend.id);
                              if (parent.mounted) {
                                await openConversation(
                                    parent, state, conversation);
                              }
                            })),
                          ),
                      ],
                    )
                  : EmptyPane(
                      icon: Icons.search_off_rounded,
                      title: 'No matches found',
                      detail: 'Try a channel name, server or username.',
                      action: _term.isEmpty
                          ? null
                          : OutlinedButton(
                              onPressed: _clear,
                              child: const Text('Clear search')),
                    ),
            ),
            Divider(color: c.line, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (MediaQuery.sizeOf(context).width >= 760)
                    Text('Enter to open first result · Esc to close',
                        style: context.label(10, color: c.muted)),
                  Text(
                      '${visibleChannels.length + servers.length + conversations.length + friends.length} results',
                      style: context.label(10, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    String? icon,
    Widget? avatar,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            if (avatar != null)
              avatar
            else if (icon != null)
              SizedBox(
                width: 24,
                child: Center(child: AppIcon(icon, size: 15, color: c.muted)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(12.5, weight: FontWeight.w600)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(10, color: c.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 15),
          ],
        ),
      ),
    );
  }
}
