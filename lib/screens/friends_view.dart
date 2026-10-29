import 'package:flutter/material.dart';

import '../app.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/icons.dart';
import 'group_dm_dialog.dart';

enum _FriendsTab { all, online, pending, blocked, add }

class FriendsView extends StatefulWidget {
  const FriendsView({this.onOpenConversation, super.key});

  final void Function(Conversation conversation)? onOpenConversation;

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  _FriendsTab _tab = _FriendsTab.all;
  String _query = '';
  bool _loading = false;
  String? _error;
  final _searchController = TextEditingController();
  final _addController = TextEditingController();
  bool _sendingRequest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final state = FlackleScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await state.loadFriends();
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _message(User user) async {
    final state = FlackleScope.read(context);
    try {
      final conversation = await state.client.createDM(user.id);
      await state.openConversation(conversation);
      if (!mounted) return;
      widget.onOpenConversation?.call(conversation);
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _remove(User user) async {
    final state = FlackleScope.read(context);
    final confirmed = await confirmAction(context,
        title: 'Remove ${user.name}?',
        body: 'They will no longer be on your friends list.',
        confirmLabel: 'Remove',
        danger: true);
    if (!confirmed) return;
    try {
      await state.client.removeFriend(user.id);
      await state.loadFriends();
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _unblock(User user) async {
    final state = FlackleScope.read(context);
    try {
      await state.client.unblockUser(user.id);
      await state.loadFriends();
      if (mounted) showAppToast(context, '${user.name} unblocked.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _sendRequest() async {
    if (_sendingRequest) return;
    final username = _addController.text.trim();
    if (username.isEmpty) return;
    final state = FlackleScope.read(context);
    setState(() => _sendingRequest = true);
    try {
      await state.client.addFriend(username);
      _addController.clear();
      await state.loadFriends();
      if (mounted) showAppToast(context, 'Friend request sent to $username.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _newGroup() async {
    final conversation = await showCreateGroupDm(context);
    if (conversation == null || !mounted) return;
    final state = FlackleScope.read(context);
    if (widget.onOpenConversation != null) {
      widget.onOpenConversation!(conversation);
    } else {
      await state.openConversation(conversation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final hasCachedData = state.friends.isNotEmpty ||
        state.blocked.isNotEmpty ||
        state.friendRequests.incoming.isNotEmpty ||
        state.friendRequests.outgoing.isNotEmpty;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
          decoration: BoxDecoration(
            color: c.panel,
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: c.accentDim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AppIcon('users', size: 21, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Friends',
                        style: context.display(20, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('A little closer to your people.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.label(12, color: c.textDim)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _newGroup,
                tooltip: 'New group',
                icon: const Icon(Icons.group_add_outlined, size: 18),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh friends',
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
        ),
        if (_tab != _FriendsTab.add)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 14),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search friends',
                prefixIcon: const Icon(Icons.search_rounded, size: 17),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                isDense: true,
              ),
            ),
          ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _tabChip(_FriendsTab.all, 'All', state.friends.length),
              _tabChip(_FriendsTab.online, 'Online',
                  state.friends.where((user) => _isOnline(state, user)).length),
              _tabChip(
                  _FriendsTab.pending,
                  'Pending',
                  state.friendRequests.incoming.length +
                      state.friendRequests.outgoing.length),
              _tabChip(_FriendsTab.blocked, 'Blocked', state.blocked.length),
              _tabChip(_FriendsTab.add, 'Add friend', null),
            ],
          ),
        ),
        if (_error != null && (hasCachedData || _tab == _FriendsTab.add))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 18, color: c.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Could not refresh friends. Try again in a moment.',
                      style: context.label(12, color: c.textDim)),
                ),
                TextButton(
                    onPressed: _loading ? null : _load,
                    child: const Text('Retry')),
              ],
            ),
          ),
        Expanded(
          child: _loading && !hasCachedData && _tab != _FriendsTab.add
              ? const LoadingPane()
              : _error != null && !hasCachedData && _tab != _FriendsTab.add
                  ? ErrorPane(message: _error!, onRetry: _load)
                  : _body(context, state),
        ),
      ],
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  bool _isOnline(AppState state, User user) {
    final presence = state.presences[user.id] ?? user.status ?? 'offline';
    return presence != 'offline' && presence != 'invisible';
  }

  bool _matches(User? user) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty ||
        (user != null &&
            (user.name.toLowerCase().contains(query) ||
                user.username.toLowerCase().contains(query)));
  }

  Widget _noMatches() => EmptyPane(
        icon: Icons.search_off_rounded,
        title: 'No matches found',
        detail: 'Try another name or username.',
        action: OutlinedButton(
          onPressed: _clearSearch,
          child: const Text('Clear search'),
        ),
      );

  Widget _tabChip(_FriendsTab tab, String label, int? count) => Padding(
        padding: const EdgeInsets.only(right: 6, top: 4),
        child: ChoiceChip(
          selected: _tab == tab,
          showCheckmark: false,
          labelStyle: context.label(12,
              color: _tab == tab ? context.c.accent : context.c.textDim,
              weight: _tab == tab ? FontWeight.w700 : FontWeight.w500),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count != null && count > 0) ...[
                const SizedBox(width: 5),
                CountBadge(count,
                    compact: true, mentions: tab == _FriendsTab.pending),
              ],
            ],
          ),
          onSelected: (_) => setState(() => _tab = tab),
        ),
      );

  Widget _body(BuildContext context, AppState state) {
    switch (_tab) {
      case _FriendsTab.add:
        return _addFriend(context, state);
      case _FriendsTab.pending:
        return _pending(context, state);
      case _FriendsTab.blocked:
        return _blocked(context, state);
      case _FriendsTab.all:
      case _FriendsTab.online:
        final friends = state.friends.where((user) {
          return _matches(user) &&
              (_tab != _FriendsTab.online || _isOnline(state, user));
        }).toList();
        if (friends.isEmpty) {
          if (_query.trim().isNotEmpty) return _noMatches();
          return EmptyPane(
            icon: Icons.people_outline_rounded,
            title:
                _tab == _FriendsTab.online ? 'Nobody online' : 'No friends yet',
            detail: _tab == _FriendsTab.online
                ? 'When friends come online they appear here.'
                : 'Use Add friend to connect with someone by username.',
            action: _tab == _FriendsTab.all
                ? FilledButton.icon(
                    onPressed: () => setState(() => _tab = _FriendsTab.add),
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Add a friend'),
                  )
                : null,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
          itemCount: friends.length,
          separatorBuilder: (_, __) =>
              Divider(color: context.c.line, height: 1),
          itemBuilder: (context, index) {
            final user = friends[index];
            final presence =
                state.presences[user.id] ?? user.status ?? 'offline';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(url: user.avatarUrl, name: user.name, size: 38),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: PresenceDot(presence, size: 10),
                  ),
                ],
              ),
              title: Text(user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('${user.handle} · $presence',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.c.muted)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _message(user),
                    tooltip: 'Message',
                    icon: const AppIcon('dm', size: 17),
                  ),
                  IconButton(
                    onPressed: () => _remove(user),
                    tooltip: 'Remove friend',
                    icon: const AppIcon('close', size: 15),
                  ),
                ],
              ),
              onTap: () => showProfile(context, user: user),
            );
          },
        );
    }
  }

  Widget _pending(BuildContext context, AppState state) {
    final c = context.c;
    final incoming = state.friendRequests.incoming
        .where((request) => _matches(request.sender))
        .toList();
    final outgoing = state.friendRequests.outgoing
        .where((request) => _matches(request.receiver))
        .toList();
    if (incoming.isEmpty && outgoing.isEmpty) {
      if (_query.trim().isNotEmpty) return _noMatches();
      return const EmptyPane(
        icon: Icons.inbox_outlined,
        title: 'No pending requests',
        detail: 'Incoming and outgoing friend requests appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
      children: [
        if (incoming.isNotEmpty) const SectionLabel('Incoming'),
        for (final request in incoming)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: AppAvatar(
              url: request.sender?.avatarUrl,
              name: request.sender?.name ?? 'Unknown',
              size: 38,
            ),
            title: Text(request.sender?.name ?? 'Unknown',
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(request.sender?.handle ?? '',
                style: TextStyle(fontSize: 10.5, color: c.muted)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () async {
                    try {
                      await state.client.acceptFriendRequest(request.id);
                      await state.loadFriends();
                    } catch (failure) {
                      if (context.mounted)
                        showAppToast(context, failure.toString());
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(70, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await state.client.rejectFriendRequest(request.id);
                      await state.loadFriends();
                    } catch (failure) {
                      if (context.mounted)
                        showAppToast(context, failure.toString());
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(66, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Ignore'),
                ),
              ],
            ),
          ),
        if (outgoing.isNotEmpty) const SectionLabel('Sent'),
        for (final request in outgoing)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: AppAvatar(
              url: request.receiver?.avatarUrl,
              name: request.receiver?.name ?? 'Unknown',
              size: 38,
            ),
            title: Text(request.receiver?.name ?? 'Unknown',
                style: const TextStyle(fontSize: 13)),
            subtitle: Text('Waiting for a response',
                style: TextStyle(fontSize: 10.5, color: c.muted)),
            trailing: TextButton(
              onPressed: () async {
                try {
                  await state.client.cancelFriendRequest(request.id);
                  await state.loadFriends();
                } catch (failure) {
                  if (context.mounted)
                    showAppToast(context, failure.toString());
                }
              },
              child: const Text('Cancel'),
            ),
          ),
      ],
    );
  }

  Widget _blocked(BuildContext context, AppState state) {
    final c = context.c;
    final blocked = state.blocked.where(_matches).toList();
    if (blocked.isEmpty) {
      if (_query.trim().isNotEmpty) return _noMatches();
      return const EmptyPane(
        icon: Icons.block_outlined,
        title: 'No blocked users',
        detail: 'People you block can be managed here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 20),
      itemCount: blocked.length,
      separatorBuilder: (_, __) => Divider(color: c.line, height: 1),
      itemBuilder: (context, index) {
        final user = blocked[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: AppAvatar(url: user.avatarUrl, name: user.name, size: 38),
          title: Text(user.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text(user.handle,
              style: TextStyle(fontSize: 10.5, color: c.muted)),
          trailing: TextButton(
              onPressed: () => _unblock(user), child: const Text('Unblock')),
        );
      },
    );
  }

  Widget _addFriend(BuildContext context, AppState state) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Text('Add a friend',
            style: context.display(20, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'You can add friends with their Flackle username. Requests are delivered instantly.',
          style: context.label(12.5, color: c.muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = TextField(
              controller: _addController,
              autocorrect: false,
              enabled: !_sendingRequest,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendRequest(),
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'username',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 17),
              ),
            );
            final button = ValueListenableBuilder<TextEditingValue>(
              valueListenable: _addController,
              builder: (context, value, _) => SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _sendingRequest || value.text.trim().isEmpty
                      ? null
                      : _sendRequest,
                  child: _sendingRequest
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Send request'),
                ),
              ),
            );
            if (constraints.maxWidth < 460) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 12), button],
              );
            }
            return Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 12),
                button
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: c.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon('shield', size: 15, color: c.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Only share your username with people you trust. Never share your password, MFA codes or session tokens.',
                  style: context.label(11.5, color: c.muted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
