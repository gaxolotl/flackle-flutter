import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';
import '../ui/navigation.dart';
import 'add_server_view.dart';
import 'channel_dialog.dart';
import 'chat_view.dart';
import 'friends_view.dart';
import 'group_dm_dialog.dart';
import 'member_panel.dart';
import 'notifications_sheet.dart';
import 'search_dialog.dart';
import 'server_channels_page.dart';
import 'server_settings_screen.dart';
import 'settings_screen.dart';

enum WorkspaceView { home, friends, server }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({required this.state, super.key});

  final AppState state;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  WorkspaceView _view = WorkspaceView.home;
  String? _serverId;
  bool _showMembers = false;
  int _mobileIndex = 0;
  int _lastActiveRevision = 0;

  AppState get state => FlackleScope.read(context);

  @override
  void initState() {
    super.initState();
    _lastActiveRevision = widget.state.activeRevision;
    _mobileIndex = widget.state.active?.isChannel == true ? 1 : 0;
    widget.state.addListener(_syncActiveTarget);
    _serverId = widget.state.active?.serverId ??
        (widget.state.servers.isEmpty ? null : widget.state.servers.first.id);
    _view = widget.state.active?.serverId != null
        ? WorkspaceView.server
        : WorkspaceView.home;
    _showMembers = widget.state.prefs.startWithMembers;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_serverId != null && widget.state.bundles[_serverId] == null) {
        unawaited(widget.state.loadBundle(_serverId!));
      }
      if (_view == WorkspaceView.server &&
          widget.state.active == null &&
          _serverId != null) {
        unawaited(widget.state.selectServer(_serverId!));
      }
    });
  }

  void _syncActiveTarget() {
    final active = widget.state.active;
    if (!mounted || widget.state.activeRevision == _lastActiveRevision) return;
    _lastActiveRevision = widget.state.activeRevision;
    if (active == null) return;
    setState(() {
      _view = active.isChannel ? WorkspaceView.server : WorkspaceView.home;
      if (active.isChannel) _serverId = active.serverId;
      _mobileIndex = active.isChannel ? 1 : 0;
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncActiveTarget);
    super.dispose();
  }

  void _selectHome() {
    setState(() => _view = WorkspaceView.home);
    if (widget.state.conversations.isNotEmpty &&
        widget.state.active?.isChannel != false) {
      unawaited(
          widget.state.openConversation(widget.state.conversations.first));
    }
  }

  void _selectFriends() => setState(() => _view = WorkspaceView.friends);

  void _selectServer(Server server) {
    setState(() {
      _view = WorkspaceView.server;
      _serverId = server.id;
      if (isNarrow(context)) _mobileIndex = 1;
    });
    unawaited(widget.state.selectServer(server.id));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const SettingsScreen(),
    ));
  }

  Future<void> _organizeServers() async {
    final state = FlackleScope.read(context);
    final organizer = _ServerOrganizer(
      state: state,
      units: _railUnits(state),
    );
    if (isNarrow(context)) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) =>
            FractionallySizedBox(heightFactor: 0.92, child: organizer),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: organizer,
          ),
        ),
      );
    }
  }

  Future<void> _openServerSettings() async {
    final serverId = _serverId ?? widget.state.active?.serverId;
    if (serverId == null) return;
    await openServerSettings(context, serverId: serverId);
  }

  Future<void> _openSearch() async {
    await showQuickSwitcher(context, serverId: _serverId, onNavigate: () {
      if (!mounted) return;
      final active = widget.state.active;
      if (active == null) return;
      setState(() {
        _view = active.isChannel ? WorkspaceView.server : WorkspaceView.home;
        if (active.isChannel) _serverId = active.serverId;
      });
    });
  }

  Future<void> _showMobileMembers(BuildContext context, String serverId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.7,
        child: MemberPanel(
          serverId: serverId,
          embedded: true,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  Future<void> _showNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => NotificationsSheet(onOpen: _openTarget),
    );
  }

  void _openTarget(Target target) {
    if (target.isChannel) {
      final channel =
          widget.state.channelById(target.serverId!, target.channelId!);
      if (channel != null) {
        unawaited(
            openChannel(context, widget.state, target.serverId!, channel));
        setState(() {
          _serverId = target.serverId;
          _view = WorkspaceView.server;
          if (isNarrow(context)) _mobileIndex = 1;
        });
      }
    } else {
      final conversation = widget.state.conversations
          .where((entry) => entry.id == target.conversationId)
          .firstOrNull;
      if (conversation != null) {
        unawaited(openConversation(context, widget.state, conversation));
        setState(() {
          _view = WorkspaceView.home;
          if (isNarrow(context)) _mobileIndex = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
      },
      child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return _mobile(context, state);
              }
              final wideMembers = constraints.maxWidth >= 1180;
              final sidebarWidth = constraints.maxWidth >= 1000 ? 264.0 : 236.0;
              return Scaffold(
                body: Row(
                  children: [
                    _rail(context, state),
                    Container(width: 1, color: context.c.line),
                    SizedBox(
                      width: sidebarWidth,
                      child: _sidebar(context, state),
                    ),
                    Container(width: 1, color: context.c.line),
                    Expanded(child: _content(context, state)),
                    if (_showMembers &&
                        wideMembers &&
                        _view == WorkspaceView.server)
                      MemberPanel(
                        serverId: state.active?.serverId ?? _serverId ?? '',
                        onClose: () => setState(() => _showMembers = false),
                      ),
                  ],
                ),
              );
            },
          )),
    );
  }

  // ---------------------------------------------------------------------------
  // Rail
  // ---------------------------------------------------------------------------

  Widget _rail(BuildContext context, AppState state) {
    final c = context.c;
    final homeActive = _view == WorkspaceView.home;
    final friendsActive = _view == WorkspaceView.friends;
    return Container(
      width: 70,
      color: c.rail,
      child: Column(
        children: [
          const SizedBox(height: 12),
          _railButton(
            context,
            tooltip: 'Direct messages',
            active: homeActive,
            onTap: _selectHome,
            child: const FlackleMark(size: 30),
          ),
          const SizedBox(height: 6),
          _railButton(
            context,
            tooltip: 'Friends',
            active: friendsActive,
            onTap: _selectFriends,
            badge: state.friendRequests.incoming.length,
            child: AppIcon('users',
                size: 21, color: friendsActive ? c.text : c.muted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Divider(color: c.line),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final unit in _railUnits(state))
                  if (unit.folder != null)
                    _railFolderButton(context, state, unit)
                  else
                    _serverButton(context, state, unit.server!),
                const SizedBox(height: 4),
                _railButton(
                  context,
                  tooltip: 'Organize servers',
                  active: false,
                  onTap: _organizeServers,
                  child: Icon(Icons.folder_outlined, size: 20, color: c.muted),
                ),
                _railButton(
                  context,
                  tooltip: 'Add a server',
                  active: false,
                  onTap: () => openAddServer(context),
                  child: Icon(Icons.add_rounded, size: 22, color: c.green),
                ),
              ],
            ),
          ),
          _railButton(
            context,
            tooltip: 'Notifications',
            active: false,
            onTap: _showNotifications,
            badge: state.unreadNotifications,
            child: AppIcon('bell', size: 19, color: c.muted),
          ),
          _railButton(
            context,
            tooltip: 'Settings',
            active: false,
            onTap: _openSettings,
            child: AppIcon('settings', size: 19, color: c.muted),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: _showYouMenu,
              child: AppAvatar(
                url: state.me?.avatarUrl,
                name: state.me?.name ?? 'You',
                size: 38,
                ring: c.accent.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railButton(
    BuildContext context, {
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
    required Widget child,
    int badge = 0,
  }) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: state.prefs.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  width: 3,
                  height: active ? 26 : 0,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: active ? c.panel3 : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active ? c.lineStrong : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: child,
                    ),
                    if (badge > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: CountBadge(badge, mentions: true, compact: true),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_RailUnit> _railUnits(AppState state) {
    final settings = state.serverSettings;
    int serverPosition(Server server) =>
        settings[server.id]?.position ?? server.position ?? 0;
    final folderIds = state.serverFolders.map((folder) => folder.id).toSet();
    final grouped = <String, List<Server>>{};
    final loose = <Server>[];
    final servers = state.servers.asMap().entries.toList()
      ..sort((a, b) {
        final byPosition =
            serverPosition(a.value).compareTo(serverPosition(b.value));
        return byPosition != 0 ? byPosition : a.key.compareTo(b.key);
      });
    for (final entry in servers) {
      final folderId = settings[entry.value.id]?.folderId;
      if (folderId != null && folderIds.contains(folderId)) {
        grouped.putIfAbsent(folderId, () => []).add(entry.value);
      } else {
        loose.add(entry.value);
      }
    }
    final folders = [...state.serverFolders]..sort((a, b) {
        final byPosition = a.effectivePosition.compareTo(b.effectivePosition);
        return byPosition != 0 ? byPosition : a.name.compareTo(b.name);
      });
    final units = <_RailUnit>[
      for (final folder in folders)
        _RailUnit.folder(
          folder,
          grouped[folder.id] ?? const [],
          folder.effectivePosition,
        ),
      for (final server in loose)
        _RailUnit.server(server, serverPosition(server)),
    ]..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        if (byPosition != 0) return byPosition;
        if (a.folder != null && b.folder == null) return -1;
        if (a.folder == null && b.folder != null) return 1;
        return 0;
      });
    return units;
  }

  Widget _railFolderButton(
      BuildContext context, AppState state, _RailUnit unit) {
    final c = context.c;
    final folder = unit.folder!;
    final active = _view == WorkspaceView.server &&
        unit.servers.any((server) =>
            _serverId == server.id || state.active?.serverId == server.id);
    final unread = unit.servers.fold<int>(
        0, (total, server) => total + state.unreadForServer(server.id));
    final mentions = unit.servers.fold<int>(
        0, (total, server) => total + state.mentionsForServer(server.id));
    final folderColor = parseHex(folder.color);
    return Tooltip(
      message: folder.name,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFolderMenu(state, unit),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: state.prefs.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  width: 3,
                  height: active ? 30 : (unread > 0 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: active ? c.accent : c.textDim,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: c.panel3,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? c.accent.withValues(alpha: 0.45)
                              : folderColor?.withValues(alpha: 0.45) ??
                                  c.lineStrong,
                        ),
                      ),
                      child: _folderPreview(unit.servers),
                    ),
                    if (mentions > 0)
                      Positioned(
                        right: -4,
                        top: -3,
                        child:
                            CountBadge(mentions, mentions: true, compact: true),
                      )
                    else if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: c.textDim,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.rail, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _folderPreview(List<Server> servers) {
    if (servers.isEmpty) {
      return const Icon(Icons.folder_outlined, size: 18);
    }
    final preview = servers.take(4).toList();
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final server in preview)
          AppAvatar(
            url: server.iconUrl,
            name: server.name,
            size: 15,
            square: true,
          ),
      ],
    );
  }

  Future<void> _showFolderMenu(AppState state, _RailUnit unit) async {
    final folder = unit.folder!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(folder.name,
                        style: context.display(17, weight: FontWeight.w600)),
                  ),
                  Text('${unit.servers.length}',
                      style: TextStyle(color: context.c.muted, fontSize: 12)),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (unit.servers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('This folder is empty.',
                          style: TextStyle(color: context.c.muted)),
                    ),
                  for (final server in unit.servers)
                    ListTile(
                      leading: AppAvatar(
                        url: server.iconUrl,
                        name: server.name,
                        size: 36,
                        square: true,
                      ),
                      title: Text(server.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: server.memberCount == null
                          ? null
                          : Text('${server.memberCount} members'),
                      trailing: _serverId == server.id ||
                              state.active?.serverId == server.id
                          ? Icon(Icons.check_rounded,
                              size: 18, color: context.c.accent)
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _selectServer(server);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serverButton(BuildContext context, AppState state, Server server) {
    final c = context.c;
    final active = _view == WorkspaceView.server &&
        (_serverId == server.id || state.active?.serverId == server.id);
    final unread = state.unreadForServer(server.id);
    final mentions = state.mentionsForServer(server.id);
    return Tooltip(
      message: server.name,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectServer(server),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: state.prefs.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  width: 3,
                  height: active ? 30 : (unread > 0 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: active ? c.accent : c.textDim,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                      url: server.iconUrl,
                      name: server.name,
                      size: 42,
                      square: true,
                      ring: active ? c.accent.withValues(alpha: 0.45) : null,
                    ),
                    if (mentions > 0)
                      Positioned(
                        right: -4,
                        bottom: -3,
                        child:
                            CountBadge(mentions, mentions: true, compact: true),
                      )
                    else if (unread > 0)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: c.textDim,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.rail, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sidebar
  // ---------------------------------------------------------------------------

  Widget _sidebar(BuildContext context, AppState state) {
    final c = context.c;
    return Container(
      color: c.sidebar,
      child: Column(
        children: [
          Expanded(
            child: _view == WorkspaceView.home || _view == WorkspaceView.friends
                ? _directMessageSidebar(context, state)
                : _serverSidebar(context, state),
          ),
          _userPanel(context, state),
        ],
      ),
    );
  }

  Widget _serverSidebar(BuildContext context, AppState state) {
    final c = context.c;
    final serverId = _serverId ?? state.active?.serverId;
    final server = serverId == null ? null : state.serverById(serverId);
    final bundle = serverId == null ? null : state.bundles[serverId];
    return Column(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
          decoration: BoxDecoration(
            color: c.sidebar,
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openServerMenu,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            server?.name ?? 'Server',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.display(15, weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 4),
                        AppIcon('chevron', size: 14, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _openSearch,
                tooltip: 'Search',
                icon: const Icon(Icons.search_rounded, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: c.input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  AppIcon('search', size: 13, color: c.muted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text('Find a channel',
                        style: context.label(11.5, color: c.muted)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.panel3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Ctrl K',
                        style: context.label(8.5,
                            color: c.muted, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: bundle == null
              ? const LoadingPane()
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 18),
                  children: _channelGroups(context, state, bundle),
                ),
        ),
        if (serverId != null && _canManage(state, serverId))
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () => openChannelCreate(context, serverId),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('New channel'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    foregroundColor: c.textDim,
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => openCategoryCreate(context, serverId),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 15),
                  label: const Text('New category'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    foregroundColor: c.textDim,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool _canManage(AppState state, String serverId) =>
      Permission.has(
          state.serverPermissions[serverId], Permission.manageChannels) ||
      Permission.has(
          state.serverPermissions[serverId], Permission.administrator);

  List<Widget> _channelGroups(
      BuildContext context, AppState state, ChannelBundle bundle) {
    final groups = <Widget>[];
    final ungrouped =
        bundle.channels.where((channel) => channel.categoryId == null).toList();
    if (ungrouped.isNotEmpty) {
      groups.add(_channelGroupHeader(context, 'Channels', null));
      groups.addAll(
          ungrouped.map((channel) => _channelRow(context, state, channel)));
    }
    for (final category in bundle.categories) {
      final channels = bundle.channels
          .where((channel) => channel.categoryId == category.id)
          .toList();
      groups.add(_channelGroupHeader(context, category.name, category,
          editable: true));
      groups.addAll(
          channels.map((channel) => _channelRow(context, state, channel)));
    }
    if (bundle.channels.isEmpty) {
      groups.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No channels yet. Create one to get started.',
            style: context.label(11.5, color: context.c.muted, height: 1.5)),
      ));
    }
    return groups;
  }

  Widget _channelGroupHeader(
    BuildContext context,
    String label,
    Category? category, {
    bool editable = false,
  }) {
    final state = FlackleScope.read(context);
    final serverId = _serverId;
    final collapsed = state.serverSettings[serverId]?.collapsedCategories
            .contains(category?.id) ??
        false;
    final c = context.c;
    return InkWell(
      onTap: category == null
          ? null
          : () {
              if (serverId == null) return;
              final current =
                  state.serverSettings[serverId]?.collapsedCategories ??
                      const <String>[];
              final next = collapsed
                  ? current.where((id) => id != category.id).toList()
                  : [...current, category.id];
              final currentSettings = state.serverSettings[serverId];
              state.serverSettings[serverId] = currentSettings == null
                  ? ServerUserSettings(
                      serverId: serverId,
                      collapsedCategories: next,
                    )
                  : currentSettings.copyWith(collapsedCategories: next);
              unawaited(state.client.updateServerUserSettings(serverId,
                  {'collapsed_categories': next}).catchError((Object _) {}));
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 8, 5),
        child: Row(
          children: [
            if (category != null)
              Icon(
                collapsed
                    ? Icons.chevron_right_rounded
                    : Icons.expand_more_rounded,
                size: 14,
                color: c.muted,
              ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: context.label(9.5,
                    weight: FontWeight.w700,
                    color: c.muted,
                    letterSpacing: 0.9),
              ),
            ),
            if (editable && _canManage(state, serverId ?? ''))
              InkWell(
                onTap: () => _categoryMenu(category!),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child:
                      Icon(Icons.more_horiz_rounded, size: 13, color: c.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _channelRow(BuildContext context, AppState state, Channel channel) {
    final c = context.c;
    final active = state.active?.channelId == channel.id;
    final unread = state.unread[channel.id];
    final mentions = unread?.mentionCount ?? 0;
    final hasUnread = (unread?.unreadCount ?? 0) > 0;
    final available = Permission.has(
            state.serverPermissions[_serverId], Permission.viewChannel) &&
        (state.channelPermissions[channel.id] == null ||
            Permission.has(
                state.channelPermissions[channel.id], Permission.viewChannel));
    if (!available && !active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => openChannel(context, state, _serverId!, channel),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: active ? c.active : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              ChannelGlyph(
                name: channel.icon,
                color: channel.iconColor,
                type: channel.type,
                size: channel.type == 'stats' ? 15 : 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: EmojiText(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.label(
                    12.5,
                    weight: hasUnread || mentions > 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: active
                        ? c.text
                        : hasUnread
                            ? c.text
                            : c.textDim,
                  ),
                ),
              ),
              if (channel.slowmodeSeconds != null &&
                  channel.slowmodeSeconds! > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: AppIcon('clock', size: 11, color: c.muted),
                ),
              if (mentions > 0)
                CountBadge(mentions, mentions: true, compact: true)
              else if (hasUnread)
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: c.textDim, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _directMessageSidebar(BuildContext context, AppState state) {
    final c = context.c;
    final query = _dmQuery;
    final conversations = state.conversations.where((conversation) {
      if (query.isEmpty) return true;
      return conversation
          .titleFor(state.me?.id ?? '')
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();
    return Column(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          decoration: BoxDecoration(
            color: c.sidebar,
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Messages',
                    style: context.display(15, weight: FontWeight.w600)),
              ),
              IconButton(
                onPressed: _newMessage,
                tooltip: 'New message',
                icon: const Icon(Icons.edit_outlined, size: 17),
              ),
              IconButton(
                onPressed: _newGroup,
                tooltip: 'New group',
                icon: const Icon(Icons.group_add_outlined, size: 17),
              ),
              IconButton(
                onPressed: _openSearch,
                tooltip: 'Search',
                icon: const Icon(Icons.search_rounded, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: TextField(
            onChanged: (value) => setState(() => _dmQuery = value),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Search conversations',
              prefixIcon: Icon(Icons.search_rounded, size: 16),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
          ),
        ),
        _dmNavRow(
          context,
          icon: 'users',
          label: 'Friends',
          badge: state.friendRequests.incoming.length,
          selected: _view == WorkspaceView.friends,
          onTap: _selectFriends,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      query.isEmpty
                          ? 'No conversations yet. Start one from Friends.'
                          : 'No conversations match "$query".',
                      textAlign: TextAlign.center,
                      style: context.label(11.5, color: c.muted, height: 1.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(6, 2, 6, 16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final other = conversation.otherUser(state.me?.id ?? '');
                    final active =
                        state.active?.conversationId == conversation.id;
                    final unread = conversation.unreadCount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () =>
                            openConversation(context, state, conversation),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? c.active : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                url: conversation.isGroup
                                    ? conversation.iconUrl
                                    : other?.avatarUrl,
                                name: conversation.isGroup
                                    ? conversation.titleFor(state.me?.id ?? '')
                                    : other?.name ??
                                        conversation
                                            .titleFor(state.me?.id ?? ''),
                                size: 34,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: EmojiText(
                                            conversation
                                                .titleFor(state.me?.id ?? ''),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.label(12.5,
                                                weight: unread > 0
                                                    ? FontWeight.w700
                                                    : FontWeight.w600),
                                          ),
                                        ),
                                        if (conversation
                                                .lastMessage?.createdAt !=
                                            null)
                                          Text(
                                            relativeTime(conversation
                                                .lastMessage!.createdAt),
                                            style: context.label(9,
                                                color: c.muted),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversation.lastMessage?.content
                                                        .isNotEmpty ==
                                                    true
                                                ? conversation
                                                    .lastMessage!.content
                                                : 'No messages yet',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.label(10.5,
                                                color: c.muted),
                                          ),
                                        ),
                                        if (unread > 0) ...[
                                          const SizedBox(width: 6),
                                          CountBadge(unread, compact: true),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _dmQuery = '';

  Widget _dmNavRow(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    int badge = 0,
  }) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.active : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 16, color: selected ? c.text : c.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: context.label(12.5,
                        weight: FontWeight.w600,
                        color: selected ? c.text : c.textDim)),
              ),
              if (badge > 0) CountBadge(badge, mentions: true, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userPanel(BuildContext context, AppState state) {
    final c = context.c;
    final me = state.me;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: c.bgSoft,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showYouMenu,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                      url: me?.avatarUrl, name: me?.name ?? 'You', size: 32),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: PresenceDot(state.presences[me?.id] ?? 'online',
                        size: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: _showYouMenu,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me?.name ?? 'You',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(12, weight: FontWeight.w600)),
                  Text(
                    _statusLabel(state.presences[me?.id]),
                    style: context.label(9.5, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Settings',
            icon: AppIcon('settings', size: 17, color: c.muted),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) => switch (status) {
        'idle' => 'Idle',
        'dnd' => 'Do not disturb',
        'invisible' => 'Invisible',
        'offline' => 'Offline',
        _ => 'Online',
      };

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  Widget _content(BuildContext context, AppState state) {
    if (_view == WorkspaceView.friends) {
      return FriendsView(onOpenConversation: (conversation) {
        unawaited(openConversation(context, state, conversation));
        setState(() => _view = WorkspaceView.home);
      });
    }
    if (_view == WorkspaceView.home) {
      final active = state.active;
      if (active != null && !active.isChannel) {
        return ChatView(
          target: active,
          onToggleMembers: null,
        );
      }
      return EmptyPane(
        icon: Icons.forum_outlined,
        title: 'Pick a conversation',
        detail:
            'Select a direct message on the left, or start a new one from Friends.',
        action: OutlinedButton.icon(
          onPressed: _newMessage,
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('New message'),
        ),
      );
    }
    final active = state.active;
    if (active == null || !active.isChannel || active.serverId != _serverId) {
      return EmptyPane(
        icon: Icons.tag_rounded,
        title: 'Choose a channel',
        detail: 'Channel history, unread pings and the composer live here.',
        action: OutlinedButton.icon(
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded, size: 15),
          label: const Text('Find a channel'),
        ),
      );
    }
    return ChatView(
      target: active,
      onToggleMembers: () {
        if (MediaQuery.sizeOf(context).width < 1180) {
          unawaited(_showMobileMembers(context, active.serverId!));
        } else {
          setState(() => _showMembers = !_showMembers);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Menus and mobile shell
  // ---------------------------------------------------------------------------

  Future<void> _openServerMenu() async {
    final state = FlackleScope.read(context);
    final serverId = _serverId;
    if (serverId == null) return;
    final server = state.serverById(serverId);
    await showAppMenu(context, title: server?.name ?? 'Server', entries: [
      MenuEntry(
        label: 'Invite people',
        icon: 'link',
        run: () => _createInvite(serverId),
      ),
      MenuEntry(
        label: 'Mark server as read',
        icon: 'check',
        run: () async {
          try {
            await state.client.markServerRead(serverId);
            state.unread.removeWhere((_, entry) => entry.serverId == serverId);
          } catch (failure) {
            if (mounted) showAppToast(context, failure.toString());
          }
        },
      ),
      MenuEntry(
        label: 'Server settings',
        icon: 'sliders',
        run: _openServerSettings,
      ),
      if (Permission.has(
          state.serverPermissions[serverId], Permission.manageChannels)) ...[
        const MenuEntry(label: '', separator: true),
        MenuEntry(
          label: 'Create channel',
          icon: 'plus',
          run: () => openChannelCreate(context, serverId),
        ),
        MenuEntry(
          label: 'Create category',
          icon: 'plus',
          run: () => openCategoryCreate(context, serverId),
        ),
      ],
      const MenuEntry(label: '', separator: true),
      MenuEntry(
        label: 'Leave server',
        icon: 'close',
        danger: true,
        run: () async {
          final confirmed = await confirmAction(context,
              title: 'Leave ${server?.name ?? 'server'}?',
              body: 'You will need an invite to return.',
              confirmLabel: 'Leave',
              danger: true);
          if (!confirmed) return;
          try {
            await state.client.leaveServer(serverId);
            state.clearServer(serverId);
            state.servers =
                state.servers.where((entry) => entry.id != serverId).toList();
            if (mounted) setState(() => _view = WorkspaceView.home);
          } catch (failure) {
            if (mounted) showAppToast(context, failure.toString());
          }
        },
      ),
    ]);
  }

  Future<void> _categoryMenu(Category category) async {
    final serverId = _serverId;
    if (serverId == null) return;
    await showAppMenu(context, title: category.name, entries: [
      MenuEntry(
        label: 'Edit category',
        icon: 'pencil',
        run: () => openCategoryEdit(context, serverId, category),
      ),
      MenuEntry(
        label: 'Create channel here',
        icon: 'plus',
        run: () =>
            openChannelCreate(context, serverId, categoryId: category.id),
      ),
      MenuEntry(
        label: 'Delete category',
        icon: 'trash',
        danger: true,
        run: () async {
          final confirmed = await confirmAction(context,
              title: 'Delete ${category.name}?',
              body: 'Channels inside move back to the top of the list.',
              confirmLabel: 'Delete',
              danger: true);
          if (!confirmed) return;
          final state = FlackleScope.read(context);
          try {
            await state.client.deleteCategory(serverId, category.id);
            await state.reloadBundle(serverId);
          } catch (failure) {
            if (mounted) showAppToast(context, failure.toString());
          }
        },
      ),
    ]);
  }

  Future<void> _createInvite(String serverId) async {
    final state = FlackleScope.read(context);
    try {
      final invite = await state.client.createServerInvite(serverId, const {});
      await Clipboard.setData(ClipboardData(text: invite.displayUrl));
      if (mounted) showAppToast(context, 'Invite copied: ${invite.displayUrl}');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _newGroup() async {
    final state = FlackleScope.read(context);
    if (state.friends.isEmpty) {
      setState(() {
        _view = WorkspaceView.friends;
        if (isNarrow(context)) _mobileIndex = 2;
      });
      return;
    }
    final conversation = await showCreateGroupDm(context);
    if (conversation == null || !mounted) return;
    await openConversation(context, state, conversation);
    if (mounted) setState(() => _view = WorkspaceView.home);
  }

  Future<void> _newMessage() async {
    final state = FlackleScope.read(context);
    if (state.friends.isEmpty) {
      setState(() {
        _view = WorkspaceView.friends;
        if (isNarrow(context)) _mobileIndex = 2;
      });
      return;
    }
    final user = await showDialog<User>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('New message',
                            style:
                                context.display(16, weight: FontWeight.w600))),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.friends.length,
                  itemBuilder: (context, index) {
                    final friend = state.friends[index];
                    return ListTile(
                      leading: AppAvatar(
                          url: friend.avatarUrl, name: friend.name, size: 34),
                      title: Text(friend.name,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(friend.handle,
                          style:
                              TextStyle(fontSize: 11, color: context.c.muted)),
                      onTap: () => Navigator.of(context).pop(friend),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (user == null) return;
    try {
      final conversation = await state.client.createDM(user.id);
      if (!mounted) return;
      await openConversation(context, state, conversation);
      if (mounted) setState(() => _view = WorkspaceView.home);
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _showYouMenu() async {
    final state = FlackleScope.read(context);
    final me = state.me;
    if (me == null) return;
    await showAppMenu(context, title: me.name, entries: [
      MenuEntry(
          label: 'Profile',
          icon: 'user',
          run: () => showProfile(context, user: me)),
      MenuEntry(
        label: 'Set status',
        icon: 'sparkles',
        run: () async {
          final status = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Set status'),
              children: [
                for (final entry in const [
                  ('online', 'Online'),
                  ('idle', 'Idle'),
                  ('dnd', 'Do not disturb'),
                  ('offline', 'Invisible'),
                ])
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(entry.$1),
                    child: Text(entry.$2),
                  ),
              ],
            ),
          );
          if (status == null) return;
          try {
            await state.client.setStatus(status);
            if (mounted) showAppToast(context, 'Status set to $status.');
          } catch (failure) {
            if (mounted) showAppToast(context, failure.toString());
          }
        },
      ),
      MenuEntry(label: 'Settings', icon: 'settings', run: _openSettings),
      const MenuEntry(label: '', separator: true),
      MenuEntry(
        label: 'Sign out',
        icon: 'close',
        danger: true,
        run: () async {
          final confirmed = await confirmAction(context,
              title: 'Sign out?',
              body: 'You can sign back in at any time.',
              confirmLabel: 'Sign out',
              danger: true);
          if (!confirmed) return;
          try {
            await state.logout();
          } catch (_) {
            // Local sign-out is already complete.
          }
        },
      ),
    ]);
  }

  Widget _mobile(BuildContext context, AppState state) {
    final pages = [
      _MobileMessages(
          state: state,
          onOpen: _openTarget,
          onCreateMessage: _newMessage,
          onSettings: _openSettings,
          onCreateGroup: _newGroup),
      _MobileServers(
        state: state,
        serverId: _serverId ?? state.active?.serverId,
        railItems: [
          for (final unit in _railUnits(state))
            if (unit.folder != null)
              _railFolderButton(context, state, unit)
            else
              _serverButton(context, state, unit.server!),
        ],
        onAdd: () => openAddServer(context),
        onOrganize: _organizeServers,
        onSearch: _openSearch,
        onServerSettings: _openServerSettings,
        onMembers: (serverId) => _showMobileMembers(context, serverId),
      ),
      FriendsView(
        onOpenConversation: (conversation) {
          unawaited(openConversation(context, state, conversation));
          setState(() => _mobileIndex = 0);
        },
      ),
      _MobileYou(
          state: state,
          onSettings: _openSettings,
          onNotifications: _showNotifications),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _mobileIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileIndex,
        height: 72,
        backgroundColor: context.c.bgSoft,
        indicatorColor: context.c.accentDim,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _mobileIndex = index),
        destinations: [
          NavigationDestination(
            icon: _navIcon('dm', false),
            selectedIcon: _navIcon('dm', true),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: _navIcon('server', false),
            selectedIcon: _navIcon('server', true),
            label: 'Servers',
          ),
          NavigationDestination(
            icon: _navIcon('users', false),
            selectedIcon: _navIcon('users', true),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: _navIcon('user', false),
            selectedIcon: _navIcon('user', true),
            label: 'You',
          ),
        ],
      ),
    );
  }

  Widget _navIcon(String name, bool selected) {
    final c = context.c;
    return AppIcon(name, size: 19, color: selected ? c.accent : c.muted);
  }
}

// -----------------------------------------------------------------------------
// Mobile pages
// -----------------------------------------------------------------------------

class _MobileMessages extends StatelessWidget {
  const _MobileMessages({
    required this.state,
    required this.onOpen,
    required this.onSettings,
    required this.onCreateGroup,
    required this.onCreateMessage,
  });

  final AppState state;
  final void Function(Target target) onOpen;
  final VoidCallback onSettings;
  final VoidCallback onCreateGroup;
  final VoidCallback onCreateMessage;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final conversations = state.conversations;
    return Column(
      children: [
        WorkspaceHeader(
          title: 'Messages',
          subtitle:
              '${state.totalUnread} unread · ${conversations.length} conversations',
          onSettings: onSettings,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                onPressed: onCreateMessage,
                tooltip: 'New message',
                icon: const Icon(Icons.edit_outlined, size: 19)),
            IconButton(
              onPressed: onCreateGroup,
              tooltip: 'New group',
              icon: const Icon(Icons.group_add_outlined, size: 19),
            ),
          ]),
        ),
        Expanded(
          child: conversations.isEmpty
              ? EmptyPane(
                  icon: Icons.forum_outlined,
                  title: 'No conversations yet',
                  detail: 'Add a friend, then start a direct message.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final other = conversation.otherUser(state.me?.id ?? '');
                    final title = conversation.titleFor(state.me?.id ?? '');
                    return Material(
                      color: c.panel,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onOpen(
                            Target.conversation(conversation.id, title: title)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          child: Row(
                            children: [
                              AppAvatar(
                                  url: conversation.isGroup
                                      ? conversation.iconUrl
                                      : other?.avatarUrl,
                                  name: conversation.isGroup
                                      ? conversation
                                          .titleFor(state.me?.id ?? '')
                                      : title,
                                  size: 42),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: EmojiText(title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.label(13.5,
                                                  weight: FontWeight.w600)),
                                        ),
                                        if (conversation
                                                .lastMessage?.createdAt !=
                                            null)
                                          Text(
                                            relativeTime(conversation
                                                .lastMessage!.createdAt),
                                            style: context.label(9.5,
                                                color: c.muted),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conversation.lastMessage?.content
                                                        .isNotEmpty ==
                                                    true
                                                ? conversation
                                                    .lastMessage!.content
                                                : 'No messages yet',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.label(11.5,
                                                color: c.muted),
                                          ),
                                        ),
                                        if (conversation.unreadCount > 0) ...[
                                          const SizedBox(width: 6),
                                          CountBadge(conversation.unreadCount,
                                              compact: true),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MobileServers extends StatelessWidget {
  const _MobileServers({
    required this.state,
    required this.serverId,
    required this.railItems,
    required this.onAdd,
    required this.onOrganize,
    required this.onSearch,
    required this.onServerSettings,
    required this.onMembers,
  });

  final AppState state;
  final String? serverId;
  final List<Widget> railItems;
  final VoidCallback onAdd;
  final VoidCallback onOrganize;
  final VoidCallback onSearch;
  final VoidCallback onServerSettings;
  final void Function(String serverId) onMembers;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final server = serverId == null ? null : state.serverById(serverId!);
    final online = server == null
        ? 0
        : state
            .membersFor(server.id)
            .where((member) =>
                (state.presences[member.user.id] ??
                    member.presence ??
                    'offline') !=
                'offline')
            .length;
    return Column(
      children: [
        WorkspaceHeader(
          title: server?.name ?? 'Servers',
          subtitle: server == null
              ? '${state.servers.length} joined'
              : '${server.memberCount ?? state.membersFor(server.id).length} members'
                  '${online > 0 ? ' · $online online' : ''}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (server != null)
                IconButton(
                  onPressed: onSearch,
                  tooltip: 'Search channels',
                  icon: const Icon(Icons.search_rounded, size: 19),
                ),
              if (server != null)
                IconButton(
                  onPressed: () => onMembers(server.id),
                  tooltip: 'Members',
                  icon: const Icon(Icons.people_alt_outlined, size: 19),
                ),
              if (server != null)
                IconButton(
                  onPressed: onServerSettings,
                  tooltip: 'Server settings',
                  icon: const Icon(Icons.settings_outlined, size: 19),
                ),
            ],
          ),
        ),
        Expanded(
          child: state.servers.isEmpty
              ? EmptyPane(
                  icon: Icons.hub_outlined,
                  title: 'No servers yet',
                  detail: 'Create a server or join one with an invite.',
                  action: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add a server'),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 66,
                      color: c.rail,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ...railItems,
                          const SizedBox(height: 4),
                          Tooltip(
                            message: 'Organize servers',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onOrganize,
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 11),
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: c.panel3,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.folder_outlined,
                                          size: 20, color: c.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Tooltip(
                            message: 'Add a server',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onAdd,
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 11),
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: c.panel3,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.add_rounded,
                                          size: 22, color: c.green),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, color: c.line),
                    Expanded(
                      child: server == null
                          ? EmptyPane(
                              icon: Icons.hub_outlined,
                              title: 'Choose a server',
                              detail:
                                  'Your servers and channels live together here.',
                            )
                          : ServerChannelsPage(
                              key: ValueKey(server.id),
                              serverId: server.id,
                              embedded: true,
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MobileYou extends StatelessWidget {
  const _MobileYou({
    required this.state,
    required this.onSettings,
    required this.onNotifications,
  });

  final AppState state;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = state.me;
    return Column(
      children: [
        WorkspaceHeader(title: 'You', subtitle: me?.handle ?? ''),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: me == null
                          ? null
                          : () => showProfile(context, user: me),
                      child: AppAvatar(
                          url: me?.avatarUrl,
                          name: me?.name ?? 'You',
                          size: 56),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me?.name ?? 'You',
                              style:
                                  context.display(18, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(me?.handle ?? '',
                              style: context.label(12, color: c.muted)),
                          const SizedBox(height: 6),
                          Tag(state.isConnected ? 'CONNECTED' : 'OFFLINE',
                              color: state.isConnected ? c.green : c.yellow,
                              small: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionLabel('Account',
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8)),
              _tile(context, 'Notifications', 'Mentions and replies',
                  Icons.notifications_none_rounded, onNotifications,
                  badge: state.unreadNotifications),
              _tile(context, 'Settings', 'Appearance, chat and security',
                  Icons.settings_outlined, onSettings),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await confirmAction(context,
                      title: 'Sign out?',
                      body: 'You can sign back in at any time.',
                      confirmLabel: 'Sign out',
                      danger: true);
                  if (!confirmed) return;
                  await state.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.danger,
                  side: BorderSide(color: c.danger.withValues(alpha: 0.35)),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    int badge = 0,
  }) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: c.panel,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 19, color: c.textDim),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: context.label(13, weight: FontWeight.w600)),
                      Text(subtitle,
                          style: context.label(10.5, color: c.muted)),
                    ],
                  ),
                ),
                if (badge > 0) ...[
                  CountBadge(badge, mentions: true, compact: true),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.chevron_right_rounded, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerOrganizer extends StatefulWidget {
  const _ServerOrganizer({required this.state, required this.units});

  final AppState state;
  final List<_RailUnit> units;

  @override
  State<_ServerOrganizer> createState() => _ServerOrganizerState();
}

class _ServerOrganizerState extends State<_ServerOrganizer> {
  late final List<_OrganizerGroup> _groups;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _groups = widget.units
        .map((unit) => _OrganizerGroup(
              folder: unit.folder,
              servers: List<Server>.of(
                  unit.folder == null ? [unit.server!] : unit.servers),
            ))
        .toList();
  }

  List<ServerFolder> get _folders =>
      _groups.map((group) => group.folder).whereType<ServerFolder>().toList();

  Future<String?> _askName(String title, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _createFolder() async {
    final name = await _askName('Create folder');
    if (name == null || !mounted) return;
    setState(() => _error = null);
    try {
      final folder = await widget.state.createServerFolder(name);
      if (!mounted) return;
      setState(() => _groups.add(_OrganizerGroup(folder: folder, servers: [])));
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    }
  }

  Future<void> _renameFolder(_OrganizerGroup group) async {
    final folder = group.folder!;
    final name = await _askName('Rename folder', initial: folder.name);
    if (name == null || name == folder.name || !mounted) return;
    setState(() => _error = null);
    try {
      final updated = await widget.state.renameServerFolder(folder.id, name);
      if (mounted) setState(() => group.folder = updated);
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    }
  }

  Future<void> _deleteFolder(_OrganizerGroup group) async {
    final folder = group.folder!;
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${folder.name}?',
      body: 'Servers in this folder will return to the main server list.',
      confirmLabel: 'Delete folder',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _error = null);
    try {
      await widget.state.deleteServerFolder(folder.id);
      if (!mounted) return;
      setState(() {
        final index = _groups.indexOf(group);
        _groups
          ..remove(group)
          ..insertAll(
            index,
            group.servers.map((server) => _OrganizerGroup(servers: [server])),
          );
      });
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    }
  }

  void _moveServer(Server server, String? folderId) {
    final sourceIndex = _groups.indexWhere(
        (group) => group.servers.any((entry) => entry.id == server.id));
    if (sourceIndex == -1) return;
    final source = _groups[sourceIndex];
    if (source.folder?.id == folderId) return;
    setState(() {
      source.servers.removeWhere((entry) => entry.id == server.id);
      if (source.folder == null) _groups.removeAt(sourceIndex);
      if (folderId == null) {
        final insertAt = source.folder == null
            ? sourceIndex.clamp(0, _groups.length)
            : (_groups.indexOf(source) + 1).clamp(0, _groups.length);
        _groups.insert(insertAt, _OrganizerGroup(servers: [server]));
      } else {
        final target =
            _groups.firstWhere((group) => group.folder?.id == folderId);
        target.servers.add(server);
      }
    });
  }

  void _moveWithinFolder(_OrganizerGroup group, int from, int to) {
    if (to < 0 || to >= group.servers.length) return;
    setState(() {
      final server = group.servers.removeAt(from);
      group.servers.insert(to, server);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final folders = <ServerFolder>[];
    final settings = <String, ServerUserSettings>{};
    for (var rootIndex = 0; rootIndex < _groups.length; rootIndex++) {
      final group = _groups[rootIndex];
      final folder = group.folder;
      if (folder != null) {
        folders.add(folder.copyWith(
          position: rootIndex,
          railPosition: rootIndex,
        ));
        for (var index = 0; index < group.servers.length; index++) {
          final server = group.servers[index];
          final current = widget.state.serverSettings[server.id];
          settings[server.id] = current == null
              ? ServerUserSettings(
                  serverId: server.id,
                  position: index,
                  folderId: folder.id,
                )
              : current.copyWith(position: index, folderId: folder.id);
        }
      } else {
        final server = group.servers.single;
        final current = widget.state.serverSettings[server.id];
        settings[server.id] = current == null
            ? ServerUserSettings(serverId: server.id, position: rootIndex)
            : current.copyWith(position: rootIndex, clearFolder: true);
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state
          .saveServerRailLayout(folders: folders, settings: settings);
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failure.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organize servers',
                        style: context.display(18, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Drag the main list, or move servers into folders.',
                        style: context.label(11, color: c.muted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _saving ? null : _createFolder,
                tooltip: 'Create folder',
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.line),
        Expanded(
          child: _groups.isEmpty
              ? const EmptyPane(
                  icon: Icons.hub_outlined,
                  title: 'No servers yet',
                  detail: 'Join a server before organizing this list.',
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  buildDefaultDragHandles: false,
                  itemCount: _groups.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final group = _groups.removeAt(oldIndex);
                      _groups.insert(newIndex, group);
                    });
                  },
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey(_groups[index].key),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _groupCard(_groups[index], index),
                  ),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text(_error!,
                style: context.label(11, color: c.danger),
                textAlign: TextAlign.center),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _saving ? null : _createFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                label: const Text('New folder'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save order'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupCard(_OrganizerGroup group, int rootIndex) {
    final c = context.c;
    final folder = group.folder;
    if (folder == null) {
      return Material(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        child: _serverRow(group.servers.single, group: group),
      );
    }
    final folderColor = parseHex(folder.color) ?? c.accent;
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: folderColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, size: 19, color: folderColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(13, weight: FontWeight.w700)),
                ),
                Text('${group.servers.length}',
                    style: context.label(10, color: c.muted)),
                PopupMenuButton<String>(
                  tooltip: 'Folder actions',
                  onSelected: (value) {
                    if (value == 'rename') _renameFolder(group);
                    if (value == 'delete') _deleteFolder(group);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'rename', child: Text('Rename folder')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete folder')),
                  ],
                ),
                ReorderableDragStartListener(
                  index: rootIndex,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.drag_handle_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (group.servers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('Empty folder',
                  style: context.label(11, color: c.muted)),
            )
          else
            for (var index = 0; index < group.servers.length; index++)
              _serverRow(
                group.servers[index],
                group: group,
                index: index,
              ),
        ],
      ),
    );
  }

  Widget _serverRow(Server server,
      {required _OrganizerGroup group, int? index}) {
    final c = context.c;
    final inFolder = group.folder != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(inFolder ? 14 : 10, 7, 4, 7),
      child: Row(
        children: [
          AppAvatar(
              url: server.iconUrl, name: server.name, size: 34, square: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(server.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.label(12.5, weight: FontWeight.w600)),
          ),
          if (inFolder) ...[
            IconButton(
              onPressed: index == 0
                  ? null
                  : () => _moveWithinFolder(group, index!, index - 1),
              tooltip: 'Move up',
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 19),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: index == group.servers.length - 1
                  ? null
                  : () => _moveWithinFolder(group, index!, index + 1),
              tooltip: 'Move down',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
              visualDensity: VisualDensity.compact,
            ),
          ],
          PopupMenuButton<String>(
            tooltip: 'Move server',
            icon: Icon(Icons.drive_file_move_outline, size: 19, color: c.muted),
            onSelected: (value) =>
                _moveServer(server, value == 'root' ? null : value),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'root',
                checked: !inFolder,
                child: const Text('No folder'),
              ),
              for (final folder in _folders)
                CheckedPopupMenuItem(
                  value: folder.id,
                  checked: group.folder?.id == folder.id,
                  child: Text(folder.name),
                ),
            ],
          ),
          if (!inFolder)
            ReorderableDragStartListener(
              index: _groups.indexOf(group),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle_rounded, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrganizerGroup {
  _OrganizerGroup({this.folder, required this.servers});

  ServerFolder? folder;
  final List<Server> servers;

  String get key =>
      folder == null ? 'server:${servers.single.id}' : 'folder:${folder!.id}';
}

class _RailUnit {
  const _RailUnit.server(this.server, this.position)
      : folder = null,
        servers = const [];

  const _RailUnit.folder(this.folder, this.servers, this.position)
      : server = null;

  final Server? server;
  final ServerFolder? folder;
  final List<Server> servers;
  final int position;
}
