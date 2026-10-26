import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/permissions.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/navigation.dart';
import 'channel_dialog.dart';
import 'member_panel.dart';
import 'search_dialog.dart';
import 'server_settings_screen.dart';

class ServerChannelsPage extends StatefulWidget {
  const ServerChannelsPage({required this.serverId, super.key});

  final String serverId;

  @override
  State<ServerChannelsPage> createState() => _ServerChannelsPageState();
}

class _ServerChannelsPageState extends State<ServerChannelsPage> {
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = FlackleScope.read(context);
      if (state.bundles[widget.serverId] == null) {
        unawaited(state.loadBundle(widget.serverId));
      }
      unawaited(state.loadMembers(widget.serverId));
      unawaited(state.loadRoles(widget.serverId));
    });
  }

  Future<void> _invite(BuildContext context) async {
    final state = FlackleScope.read(context);
    try {
      final invite =
          await state.client.createServerInvite(widget.serverId, const {});
      await Clipboard.setData(ClipboardData(text: invite.displayUrl));
      if (context.mounted)
        showAppToast(context, 'Invite copied: ${invite.displayUrl}');
    } catch (failure) {
      if (context.mounted) showAppToast(context, failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final server = state.serverById(widget.serverId);
    final bundle = state.bundles[widget.serverId];
    final canManage = Permission.has(
          state.serverPermissions[widget.serverId],
          Permission.manageChannels,
        ) ||
        Permission.has(
            state.serverPermissions[widget.serverId], Permission.administrator);
    final online = state
        .membersFor(widget.serverId)
        .where((member) =>
            (state.presences[member.user.id] ?? member.presence ?? 'offline') !=
            'offline')
        .length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(
              url: server?.iconUrl,
              name: server?.name ?? 'Server',
              size: 32,
              square: true,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiText(server?.name ?? 'Server',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.display(15, weight: FontWeight.w600)),
                  Text(
                    '${server?.memberCount ?? state.membersFor(widget.serverId).length} members'
                    '${online > 0 ? ' · $online online' : ''}',
                    style: context.label(10, color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () =>
                showQuickSwitcher(context, serverId: widget.serverId),
            tooltip: 'Search channels',
            icon: const Icon(Icons.search_rounded, size: 19),
          ),
          IconButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: MemberPanel(
                  serverId: widget.serverId,
                  embedded: true,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            tooltip: 'Members',
            icon: const Icon(Icons.people_alt_outlined, size: 19),
          ),
          IconButton(
            onPressed: () =>
                openServerSettings(context, serverId: widget.serverId),
            tooltip: 'Server settings',
            icon: const Icon(Icons.settings_outlined, size: 19),
          ),
        ],
      ),
      body: state.loading && bundle == null
          ? const LoadingPane()
          : bundle == null
              ? ErrorPane(
                  message: state.error ?? 'Could not load channels.',
                  onRetry: () => state.loadBundle(widget.serverId, force: true),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await state.loadBundle(widget.serverId, force: true);
                    await state.loadMembers(widget.serverId, force: true);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      if (server?.description?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Text(
                            server!.description!,
                            style:
                                context.label(12, color: c.muted, height: 1.5),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _invite(context),
                                icon: const Icon(Icons.link_rounded, size: 16),
                                label: const Text('Invite'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await state.client
                                        .markServerRead(widget.serverId);
                                    state.unread.removeWhere((_, entry) =>
                                        entry.serverId == widget.serverId);
                                    if (context.mounted) {
                                      showAppToast(
                                          context, 'Server marked as read.');
                                    }
                                  } catch (failure) {
                                    if (context.mounted) {
                                      showAppToast(context, failure.toString());
                                    }
                                  }
                                },
                                icon: const Icon(Icons.done_all_rounded,
                                    size: 16),
                                label: const Text('Mark read'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final group
                          in _groups(context, state, bundle, canManage))
                        ...group,
                      if (canManage)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                          child: Column(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () =>
                                    openChannelCreate(context, widget.serverId),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Create channel'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(42),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => openCategoryCreate(
                                    context, widget.serverId),
                                icon: const Icon(
                                    Icons.create_new_folder_outlined,
                                    size: 16),
                                label: const Text('Create category'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(42),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  List<List<Widget>> _groups(
    BuildContext context,
    AppState state,
    ChannelBundle bundle,
    bool canManage,
  ) {
    final groups = <List<Widget>>[];
    final ungrouped =
        bundle.channels.where((channel) => channel.categoryId == null).toList();
    if (ungrouped.isNotEmpty) {
      groups.add([
        _header(context, 'Channels', null, canManage),
        ...ungrouped.map((channel) => _row(context, state, channel)),
      ]);
    }
    for (final category in bundle.categories) {
      final channels = bundle.channels
          .where((channel) => channel.categoryId == category.id)
          .toList();
      groups.add([
        _header(context, category.name, category, canManage),
        if (!_collapsed.contains(category.id))
          ...channels.map((channel) => _row(context, state, channel)),
      ]);
    }
    return groups;
  }

  Widget _header(
      BuildContext context, String label, Category? category, bool canManage) {
    final c = context.c;
    final collapsed = category != null && _collapsed.contains(category.id);
    return InkWell(
      onTap: category == null
          ? null
          : () => setState(() {
                if (collapsed) {
                  _collapsed.remove(category.id);
                } else {
                  _collapsed.add(category.id);
                }
              }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 10, 6),
        child: Row(
          children: [
            if (category != null)
              Icon(
                collapsed
                    ? Icons.chevron_right_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: c.muted,
              ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: context.label(10,
                    weight: FontWeight.w700, color: c.muted, letterSpacing: 1),
              ),
            ),
            if (category != null && canManage)
              PopupMenuButton<String>(
                tooltip: 'Category options',
                icon: Icon(Icons.more_horiz_rounded, size: 16, color: c.muted),
                onSelected: (value) async {
                  final state = FlackleScope.read(context);
                  if (value == 'edit') {
                    await openCategoryEdit(context, widget.serverId, category);
                  } else if (value == 'channel') {
                    await openChannelCreate(context, widget.serverId,
                        categoryId: category.id);
                  } else if (value == 'delete') {
                    final confirmed = await confirmAction(context,
                        title: 'Delete ${category.name}?',
                        body: 'Channels inside move back to the top.',
                        confirmLabel: 'Delete',
                        danger: true);
                    if (!confirmed) return;
                    try {
                      await state.client
                          .deleteCategory(widget.serverId, category.id);
                      await state.reloadBundle(widget.serverId);
                    } catch (failure) {
                      if (context.mounted)
                        showAppToast(context, failure.toString());
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit category')),
                  PopupMenuItem(
                      value: 'channel', child: Text('Create channel here')),
                  PopupMenuItem(
                      value: 'delete', child: Text('Delete category')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppState state, Channel channel) {
    final c = context.c;
    final active = state.active?.channelId == channel.id;
    final unread = state.unread[channel.id];
    final mentions = unread?.mentionCount ?? 0;
    final hasUnread = (unread?.unreadCount ?? 0) > 0;
    final unavailable = !Permission.has(
      state.channelPermissions[channel.id] ??
          state.serverPermissions[widget.serverId],
      Permission.viewChannel,
    );
    if (unavailable) return const SizedBox.shrink();
    return InkWell(
      onTap: () => openChannel(context, state, widget.serverId, channel),
      onLongPress: () {
        if (Permission.has(state.serverPermissions[widget.serverId],
            Permission.manageChannels)) {
          openChannelEdit(context, widget.serverId, channel);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.active : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            ChannelGlyph(
              name: channel.icon,
              color: channel.iconColor,
              type: channel.type,
              size: 17,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiText(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.label(
                      13,
                      weight: hasUnread || mentions > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: hasUnread || mentions > 0 || active
                          ? c.text
                          : c.textDim,
                    ),
                  ),
                  if (channel.topic?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(channel.topic!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(10.5, color: c.muted)),
                    ),
                ],
              ),
            ),
            if (channel.type == 'voice' || channel.type == 'stats')
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  channel.type == 'voice'
                      ? Icons.volume_off_outlined
                      : Icons.bar_chart_rounded,
                  size: 14,
                  color: c.muted,
                ),
              ),
            if (mentions > 0)
              CountBadge(mentions, mentions: true)
            else if (hasUnread)
              CountBadge(unread?.unreadCount ?? 0),
          ],
        ),
      ),
    );
  }
}

/// Alias used by the quick switcher when it needs the channel list on mobile.
typedef ServerChannelsProxy = ServerChannelsPage;
