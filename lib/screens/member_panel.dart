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
    final online =
        all.where((member) => onlineIds.contains(member.id)).toList();
    final offline =
        all.where((member) => !onlineIds.contains(member.id)).toList();
    final filtered = _query.isEmpty
        ? all
        : all
            .where((member) =>
                member.displayName
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                member.user.username
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();
    final onlineFiltered =
        filtered.where((member) => onlineIds.contains(member.id)).toList();
    final offlineFiltered =
        filtered.where((member) => !onlineIds.contains(member.id)).toList();

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
                    icon: const Icon(Icons.close_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Search members',
                prefixIcon: Icon(Icons.search_rounded, size: 16),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? const LoadingPane()
                : Builder(builder: (context) {
                    final entries = <Object>[];
                    if (onlineFiltered.isNotEmpty) {
                      entries
                          .add(_MemberSection('ONLINE  -  ${online.length}'));
                      entries.addAll(onlineFiltered);
                    }
                    if (offlineFiltered.isNotEmpty) {
                      entries
                          .add(_MemberSection('OFFLINE  -  ${offline.length}'));
                      entries.addAll(offlineFiltered);
                    }
                    if (filtered.isEmpty) {
                      entries.add('No members match "${_query.trim()}".');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 18),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        if (entry is _MemberSection) {
                          return _section(entry.label);
                        }
                        if (entry is String) {
                          return Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(entry,
                                style: TextStyle(color: c.muted, fontSize: 12)),
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

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 5),
        child: Text(
          label,
          style: context.label(9.5,
              weight: FontWeight.w700,
              color: context.c.muted,
              letterSpacing: 0.9),
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
                          if (memberRoles.first.iconEmoji != null) ...[
                            EmojiGlyph(memberRoles.first.iconEmoji!, size: 9),
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
  const _MemberSection(this.label);

  final String label;
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
