import 'package:flutter/material.dart';

import '../core/media.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';
import 'profile_editor_screen.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({
    required this.user,
    this.member,
    this.serverId,
    this.controller,
    super.key,
  });

  final User user;
  final Member? member;
  final String? serverId;
  final ScrollController? controller;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  UserCard? _card;
  bool _loading = true;
  bool _busy = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    try {
      final card = await state.client
          .fetchUserCard(widget.user.username, serverId: widget.serverId);
      if (mounted) setState(() => _card = card);
    } catch (_) {
      // Fall back to the user we already have.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _message() async {
    final state = FlackleScope.read(context);
    setState(() => _busy = true);
    try {
      final conversation = await state.client.createDM(widget.user.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      await state.openConversation(conversation);
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFriend() async {
    final state = FlackleScope.read(context);
    setState(() => _busy = true);
    try {
      await state.client.addFriend(widget.user.username);
      await state.loadFriends();
      if (!mounted) return;
      setState(() => _requested = true);
      showAppToast(context, 'Friend request sent to @${widget.user.username}.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptFriend(String requestId) async {
    final state = FlackleScope.read(context);
    setState(() => _busy = true);
    try {
      await state.client.acceptFriendRequest(requestId);
      await state.loadFriends();
      if (mounted) showAppToast(context, 'Friend request accepted.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moderate() async {
    final state = FlackleScope.read(context);
    final serverId = widget.serverId;
    if (serverId == null) return;
    final canKick = state.can(PermissionBits.kick, serverId: serverId);
    final canBan = state.can(PermissionBits.ban, serverId: serverId);
    if (!canKick && !canBan) return;
    await showAppMenu(context, title: widget.user.name, entries: [
      if (canKick)
        MenuEntry(
          label: 'Kick from server',
          icon: 'close',
          danger: true,
          run: () async {
            final confirmed = await confirmAction(context,
                title: 'Kick ${widget.user.name}?',
                body: 'They can be invited back later.',
                confirmLabel: 'Kick',
                danger: true);
            if (!confirmed) return;
            try {
              await state.client.kickMember(serverId, widget.user.id);
              if (context.mounted) showAppToast(context, 'Member kicked.');
            } catch (failure) {
              if (context.mounted) showAppToast(context, failure.toString());
            }
          },
        ),
      if (canBan)
        MenuEntry(
          label: 'Ban from server',
          icon: 'ban',
          danger: true,
          run: () async {
            final confirmed = await confirmAction(context,
                title: 'Ban ${widget.user.name}?',
                body: 'They will be removed and blocked from rejoining.',
                confirmLabel: 'Ban',
                danger: true);
            if (!confirmed) return;
            try {
              await state.client.banMember(serverId, widget.user.id);
              if (context.mounted) showAppToast(context, 'Member banned.');
            } catch (failure) {
              if (context.mounted) showAppToast(context, failure.toString());
            }
          },
        ),
    ]);
  }

  Future<void> _safetyMenu() async {
    final state = FlackleScope.read(context);
    final canManage = widget.serverId != null &&
        (state.can(PermissionBits.kick, serverId: widget.serverId) ||
            state.can(PermissionBits.ban, serverId: widget.serverId));
    await showAppMenu(context, title: 'Safety', entries: [
      MenuEntry(
        label: 'Copy username',
        icon: 'copy',
        run: () async {
          await Clipboard.setData(ClipboardData(text: widget.user.handle));
          if (context.mounted) showAppToast(context, 'Username copied.');
        },
      ),
      MenuEntry(
        label: 'Block user',
        icon: 'ban',
        danger: true,
        run: () async {
          final confirmed = await confirmAction(context,
              title: 'Block ${widget.user.name}?',
              body: 'They will not be able to message you.',
              confirmLabel: 'Block',
              danger: true);
          if (!confirmed) return;
          try {
            await state.client.blockUser(widget.user.id);
            if (context.mounted) showAppToast(context, 'User blocked.');
          } catch (failure) {
            if (context.mounted) showAppToast(context, failure.toString());
          }
        },
      ),
      MenuEntry(label: 'Report user', icon: 'alert', run: _report),
      if (canManage) ...[
        const MenuEntry(label: '', separator: true),
        MenuEntry(
            label: 'Moderate member',
            icon: 'shield',
            danger: true,
            run: _moderate),
      ],
    ]);
  }

  Future<void> _report() async {
    final state = FlackleScope.read(context);
    final details = TextEditingController();
    String category = 'harassment';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Report ${widget.user.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment or bullying')),
                  DropdownMenuItem(value: 'spam', child: Text('Spam or scam')),
                  DropdownMenuItem(
                      value: 'inappropriate',
                      child: Text('Inappropriate content')),
                  DropdownMenuItem(
                      value: 'impersonation', child: Text('Impersonation')),
                  DropdownMenuItem(
                      value: 'other', child: Text('Something else')),
                ],
                onChanged: (value) =>
                    setDialogState(() => category = value ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'What should Flackle know?',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) {
      details.dispose();
      return;
    }
    try {
      await state.client
          .reportUser(widget.user.id, category, details.text.trim());
      if (mounted) showAppToast(context, 'Report sent to Flackle.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
    details.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final card = _card;
    final user = card?.user ?? widget.user;
    final member = card?.member ?? widget.member;
    final roles = <Role>[];
    if (widget.serverId != null && member != null) {
      for (final id in member.roleIds) {
        final role = state.roleById(widget.serverId!, id);
        if (role != null) roles.add(role);
      }
    }
    final blocks = card?.blocks ?? const <ProfileBlock>[];
    final isMe = state.me?.id == user.id;
    final isFriend = state.friends.any((entry) => entry.id == user.id);
    final outgoing = state.friendRequests.outgoing
        .any((request) => request.receiver?.id == user.id);
    final incoming = state.friendRequests.incoming
        .where((request) => request.sender?.id == user.id)
        .toList();
    final pendingIncoming = incoming.isEmpty ? null : incoming.first;

    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: widget.controller,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 178,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 140,
                  child: user.bannerUrl != null
                      ? AppImage(
                          user.bannerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.panel2,
                            border: Border(bottom: BorderSide(color: c.line)),
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Opacity(
                                opacity: 0.12,
                                child: FlackleMark(size: 84, color: c.text),
                              ),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      if (widget.serverId != null)
                        IconButton(
                          onPressed: _safetyMenu,
                          style: IconButton.styleFrom(
                            backgroundColor: c.bg.withValues(alpha: 0.5),
                          ),
                          icon: const Icon(Icons.more_horiz_rounded, size: 18),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 10,
                  child: AppAvatar(
                    url: user.avatarUrl,
                    name: user.name,
                    size: 74,
                    ring: c.panel,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EmojiText(user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.display(21,
                                  weight: FontWeight.w600,
                                  letterSpacing: -0.4)),
                          const SizedBox(height: 3),
                          Text(user.handle,
                              style: context.label(12.5, color: c.muted)),
                        ],
                      ),
                    ),
                    if (member?.isOwner == true)
                      const Tag('OWNER', color: Color(0xFFE0A13D)),
                    if (state.presences[user.id] != null) ...[
                      const SizedBox(width: 6),
                      Tag(state.presences[user.id]!,
                          color: c.green, small: true),
                    ],
                  ],
                ),
                if (roles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final role in roles) RolePill(role)],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!isMe) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Message',
                          icon: 'dm',
                          onPressed: _busy ? null : _message,
                          busy: _busy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _busy || isFriend || outgoing || _requested
                            ? null
                            : pendingIncoming != null
                                ? () => _acceptFriend(pendingIncoming.id)
                                : _addFriend,
                        child: Text(isFriend
                            ? 'Friends'
                            : (outgoing || _requested)
                                ? 'Request sent'
                                : pendingIncoming != null
                                    ? 'Accept request'
                                    : 'Add friend'),
                      ),
                    ] else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            await navigator.push<void>(MaterialPageRoute(
                              builder: (_) => const ProfileEditorScreen(),
                            ));
                            if (mounted) navigator.pop();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit profile'),
                        ),
                      ),
                  ],
                ),
                if (member != null) ...[
                  const SizedBox(height: 18),
                  _detailRow(
                      'Member since',
                      member.joinedAt == null
                          ? 'Unknown'
                          : formatProfileDate(member.joinedAt!)),
                  if (member.nickname?.isNotEmpty == true)
                    _detailRow('Server nickname', member.nickname!),
                ],
                for (final block in blocks) _block(context, block),
                if (card?.membership != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Tag('${card!.membership!.toUpperCase()} MEMBER',
                        color: c.accent),
                  ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: c.panel3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 108,
              child: Text(label,
                  style: context.label(11,
                      color: context.c.muted, weight: FontWeight.w600)),
            ),
            Expanded(
                child: Text(value,
                    style: context.label(12.5, color: context.c.textDim))),
          ],
        ),
      );

  Widget _block(BuildContext context, ProfileBlock block) {
    final c = context.c;
    switch (block.type) {
      case 'header':
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            block.content ?? '',
            style: context.display(
              block.level == 1
                  ? 22
                  : block.level == 2
                      ? 18
                      : 15,
              weight: FontWeight.w600,
            ),
          ),
        );
      case 'text':
      case 'about':
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(block.content ?? '',
              style: context.label(13, color: c.textDim, height: 1.55)),
        );
      case 'social':
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              AppIcon('link', size: 14, color: c.muted),
              const SizedBox(width: 7),
              Text(block.platform ?? 'social',
                  style: context.label(11,
                      color: c.muted, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('@${block.username ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.label(12.5, color: c.textDim)),
              ),
            ],
          ),
        );
      case 'link':
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: InkWell(
            onTap: block.url == null
                ? null
                : () => launchUrl(Uri.parse(block.url!),
                    mode: LaunchMode.externalApplication),
            child: Row(
              children: [
                AppIcon('link', size: 14, color: c.accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(block.content ?? block.url ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(12.5, color: c.accent)),
                ),
              ],
            ),
          ),
        );
      case 'image':
        if (block.imageUrl == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AppImage(block.imageUrl!, fit: BoxFit.cover),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

String formatProfileDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Permission bit shortcuts used by profile actions.
class PermissionBits {
  static const kick = 1 << 6;
  static const ban = 1 << 7;
}

/// Re-exported for screens that do not want to import the emoji module.
typedef ProfileEmoji = EmojiGlyph;
