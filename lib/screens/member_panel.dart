import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';

class MemberPanel extends StatefulWidget {
  const MemberPanel({
    required this.serverId,
    this.onClose,
    this.embedded = false,
    super.key,
  });

  final String serverId;
  final VoidCallback? onClose;
  final bool embedded;

  @override
  State<MemberPanel> createState() => _MemberPanelState();
}

class _MemberPanelState extends State<MemberPanel> {
  String _query = '';
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant MemberPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverId != widget.serverId) {
      _search.clear();
      _query = '';
      _loading = true;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final state = FlackleScope.read(context);
    final serverId = widget.serverId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        state.loadMembers(serverId, force: force),
        state.loadRoles(serverId, force: force),
      ]);
      if (!state.members.containsKey(serverId)) {
        throw StateError(
            'Could not load members. Check your connection and try again.');
      }
    } catch (_) {
      if (mounted && widget.serverId == serverId) {
        setState(() => _error =
            'Could not load members. Check your connection and try again.');
      }
    } finally {
      if (mounted && widget.serverId == serverId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final roles = state.roles[widget.serverId] ?? const <Role>[];
    final all = state.membersFor(widget.serverId);
    final onlineIds = <String>{};
    for (final member in all) {
      final presence =
          state.presences[member.user.id] ?? member.presence ?? 'offline';
      if (presence != 'offline' && presence != 'invisible') {
        onlineIds.add(member.id);
      }
    }
    final term = _query.trim().toLowerCase();
    final filtered = term.isEmpty
        ? all
        : all
            .where((member) =>
                member.displayName.toLowerCase().contains(term) ||
                member.user.username.toLowerCase().contains(term))
            .toList();
    final hoistedRoles = roles
        .where((role) => role.hoist && !role.isEveryone)
        .toList()
      ..sort((a, b) => b.position.compareTo(a.position));
    final byRole = <String, List<Member>>{};
    final ungrouped = <Member>[];
    for (final member in filtered) {
      Role? group;
      for (final role in hoistedRoles) {
        if (member.roleIds.contains(role.id)) {
          group = role;
          break;
        }
      }
      if (group == null) {
        ungrouped.add(member);
      } else {
        byRole.putIfAbsent(group.id, () => []).add(member);
      }
    }
    int compareMembers(Member a, Member b) {
      final aOnline = onlineIds.contains(a.id);
      final bOnline = onlineIds.contains(b.id);
      if (aOnline != bOnline) return aOnline ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    }

    for (final list in byRole.values) {
      list.sort(compareMembers);
    }
    ungrouped.sort(compareMembers);
    final onlineFiltered =
        ungrouped.where((member) => onlineIds.contains(member.id)).toList();
    final offlineFiltered =
        ungrouped.where((member) => !onlineIds.contains(member.id)).toList();

    return Container(
      width: widget.embedded ? null : 236,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(left: BorderSide(color: c.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                Text(
                  'MEMBERS',
                  style: context.label(10,
                      weight: FontWeight.w700,
                      color: c.muted,
                      letterSpacing: 1.05),
                ),
                const Spacer(),
                Text('${all.length}',
                    style: context.label(10.5, color: c.muted)),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Close members',
                    icon: const Icon(Icons.close_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search members',
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          Expanded(
            child: _loading && all.isEmpty
                ? const LoadingPane()
                : _error != null && all.isEmpty
                    ? ErrorPane(
                        message: _error!, onRetry: () => _load(force: true))
                    : all.isEmpty
                        ? const EmptyPane(
                            icon: Icons.people_outline_rounded,
                            title: 'No members yet',
                            detail: 'Members will appear here when they join.')
                        : Builder(builder: (context) {
                            final entries = <Object>[];
                            for (final role in hoistedRoles) {
                              final list = byRole[role.id];
                              if (list == null || list.isEmpty) continue;
                              entries.add(_MemberSection(
                                '${role.name.toUpperCase()}  -  ${list.length}',
                                role: role,
                              ));
                              entries.addAll(list);
                            }
                            if (onlineFiltered.isNotEmpty) {
                              entries.add(_MemberSection(
                                  'ONLINE  -  ${onlineFiltered.length}'));
                              entries.addAll(onlineFiltered);
                            }
                            if (offlineFiltered.isNotEmpty) {
                              entries.add(_MemberSection(
                                  'OFFLINE  -  ${offlineFiltered.length}'));
                              entries.addAll(offlineFiltered);
                            }
                            if (filtered.isEmpty) {
                              entries
                                  .add('No members match "${_query.trim()}".');
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 18),
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                if (entry is _MemberSection) {
                                  return _section(entry.label,
                                      role: entry.role);
                                }
                                if (entry is String) {
                                  return Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Text(entry,
                                        style: TextStyle(
                                            color: c.muted, fontSize: 12)),
                                  );
                                }
                                final member = entry as Member;
                                return _memberRow(context, state, member, roles,
                                    onlineIds.contains(member.id));
                              },
                            );
                          }),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, {Role? role}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 5),
        child: Row(
          children: [
            if (role != null &&
                (role.iconUrl?.isNotEmpty == true ||
                    role.iconEmoji?.isNotEmpty == true)) ...[
              RoleIcon(role: role, size: 11),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                label,
                style: context.label(9.5,
                    weight: FontWeight.w700,
                    color: context.c.muted,
                    letterSpacing: 0.9),
              ),
            ),
          ],
        ),
      );

  Widget _memberRow(
    BuildContext context,
    AppState state,
    Member member,
    List<Role> roles,
    bool online,
  ) {
    final c = context.c;
    final memberRoles = roles.where((role) {
      if (role.isEveryone) return false;
      return member.roleIds.contains(role.id);
    }).toList()
      ..sort((a, b) => b.position.compareTo(a.position));
    final topRole = memberRoles.isEmpty ? null : memberRoles.first;
    final nameColor = topRole?.color != null ? parseHex(topRole!.color) : null;
    final presence =
        state.presences[member.user.id] ?? member.presence ?? 'offline';
    return InkWell(
      onTap: () => showProfile(
        context,
        user: member.user,
        member: member,
        serverId: widget.serverId,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: online ? 1 : 0.45,
                  child: AppAvatar(
                    url: member.user.avatarUrl,
                    name: member.displayName,
                    size: 30,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: PresenceDot(presence, size: 9),
                ),
              ],
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (topRole != null &&
                          (topRole.iconUrl?.isNotEmpty == true ||
                              topRole.iconEmoji?.isNotEmpty == true)) ...[
                        RoleIcon(role: topRole, size: 12),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: EmojiText(
                          member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(
                            12.5,
                            weight: online ? FontWeight.w600 : FontWeight.w500,
                            color: online ? (nameColor ?? c.text) : c.muted,
                          ),
                        ),
                      ),
                      if (member.isOwner) ...[
                        const SizedBox(width: 4),
                        const AppIcon('crown',
                            size: 11, color: Color(0xFFE0A13D)),
                      ],
                    ],
                  ),
                  if (memberRoles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          if (memberRoles.first.iconUrl?.isNotEmpty == true ||
                              memberRoles.first.iconEmoji?.isNotEmpty ==
                                  true) ...[
                            RoleIcon(role: memberRoles.first, size: 10),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              memberRoles.first.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: (parseHex(memberRoles.first.color) ??
                                        c.muted)
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
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
}

class _MemberSection {
  const _MemberSection(this.label, {this.role});

  final String label;
  final Role? role;
}

Color? parseHex(String? hex) {
  if (hex == null || !hex.startsWith('#')) return null;
  final value = hex.substring(1);
  final normalized = value.length == 3
      ? value.split('').map((char) => '$char$char').join()
      : value.padRight(6, '0').substring(0, 6);
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
