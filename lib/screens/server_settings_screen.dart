import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';

Future<void> openServerSettings(BuildContext context,
    {required String serverId}) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => ServerSettingsScreen(serverId: serverId),
  ));
}

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({required this.serverId, super.key});

  final String serverId;

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  int _tab = 0;

  static const _tabs = [
    ('server', 'Overview'),
    ('crown', 'Roles'),
    ('users', 'Members'),
    ('link', 'Invites'),
    ('ban', 'Bans'),
    ('shield', 'Audit log'),
    ('gift', 'Lifts'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final server = state.serverById(widget.serverId);
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final children = [
      _OverviewTab(serverId: widget.serverId),
      _RolesTab(serverId: widget.serverId),
      _MembersTab(serverId: widget.serverId),
      _InvitesTab(serverId: widget.serverId),
      _BansTab(serverId: widget.serverId),
      _AuditTab(serverId: widget.serverId),
      _LiftsTab(serverId: widget.serverId),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(server?.name ?? 'Server settings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.display(16, weight: FontWeight.w600)),
            Text('Server settings',
                style: context.label(10, color: context.c.muted)),
          ],
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 220,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                    children: [
                      for (var index = 0; index < _tabs.length; index++)
                        SettingsNavItem(
                            icon: _tabs[index].$1,
                            label: _tabs[index].$2,
                            selected: _tab == index,
                            onTap: () => setState(() => _tab = index)),
                    ],
                  ),
                ),
                VerticalDivider(width: 1, color: context.c.line),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: SizedBox(
                            width: double.infinity,
                            child: children[_tab],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                AppSectionTabs(
                    tabs: _tabs,
                    selectedIndex: _tab,
                    onSelected: (index) => setState(() => _tab = index)),
                Divider(height: 1, color: context.c.line),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                    children: [children[_tab]],
                  ),
                ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Overview
// -----------------------------------------------------------------------------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.serverId});

  final String serverId;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _notificationLevel;
  bool _initialised = false;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    final server = FlackleScope.read(context).serverById(widget.serverId);
    _name.text = server?.name ?? '';
    _description.text = server?.description ?? '';
    _notificationLevel = server?.defaultNotificationLevel ?? 'all';
    _initialised = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = FlackleScope.read(context);
    setState(() => _busy = true);
    try {
      final server = await state.client.updateServer(widget.serverId, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        if (_notificationLevel != null)
          'default_notification_level': _notificationLevel,
      });
      state.servers = state.servers
          .map((entry) => entry.id == server.id ? server : entry)
          .toList();
      if (mounted) showAppToast(context, 'Server updated.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadIcon() async {
    final state = FlackleScope.read(context);
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.image,
      );
    } catch (failure) {
      if (mounted)
        showAppToast(context, 'Could not open the file picker: $failure');
      return;
    }
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final url = await state.client
          .uploadServerIcon(widget.serverId, file.name, file.bytes!);
      final server = state.serverById(widget.serverId);
      if (server != null) {
        state.servers = state.servers
            .map((entry) => entry.id == server.id
                ? Server(
                    id: server.id,
                    name: server.name,
                    description: server.description,
                    iconUrl: url,
                    bannerUrl: server.bannerUrl,
                    ownerId: server.ownerId,
                    defaultNotificationLevel: server.defaultNotificationLevel,
                    position: server.position,
                    memberCount: server.memberCount,
                    presenceCount: server.presenceCount,
                    flags: server.flags,
                    verified: server.verified,
                    createdAt: server.createdAt,
                  )
                : entry)
            .toList();
      }
      if (mounted) showAppToast(context, 'Server icon updated.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final server = state.serverById(widget.serverId);
    final c = context.c;
    final canManage = Permission.has(
      state.serverPermissions[widget.serverId],
      Permission.manageServer,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: context.display(18, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: canManage ? _uploadIcon : null,
              child: Stack(
                children: [
                  AppAvatar(
                    url: server?.iconUrl,
                    name: server?.name ?? 'Server',
                    size: 70,
                    square: true,
                  ),
                  if (canManage)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black
                              .withValues(alpha: _uploading ? 0.42 : 0),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        alignment: Alignment.center,
                        child: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canManage)
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _uploadIcon,
                      icon: const Icon(Icons.upload_rounded, size: 15),
                      label: const Text('Change icon'),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    canManage
                        ? 'PNG, JPEG, GIF or WebP. Square icons look best.'
                        : 'Only server managers can change the icon.',
                    style: context.label(10.5, color: c.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SectionLabel('Identity'),
        TextField(
          controller: _name,
          enabled: canManage,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Server name'),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _description,
          enabled: canManage,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _notificationLevel ?? 'all',
          decoration: const InputDecoration(
            labelText: 'Default notification level',
            helperText: 'Applied to new members who join the server.',
          ),
          items: const [
            DropdownMenuItem(
                value: 'all',
                child: Text('All messages',
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(
                value: 'mentions',
                child: Text('Mentions only',
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: 'nothing', child: Text('Nothing')),
          ],
          onChanged: canManage
              ? (value) => setState(() => _notificationLevel = value)
              : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const SizedBox(width: 4),
            _stat(context, 'Members', '${server?.memberCount ?? 0}'),
            const SizedBox(width: 8),
            _stat(context, 'Online', '${server?.presenceCount ?? 0}'),
            const SizedBox(width: 8),
            _stat(context, 'Channels',
                '${state.channelsFor(widget.serverId).length}'),
          ],
        ),
        if (canManage) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ),
          ),
        ],
        const SectionLabel('Danger zone'),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await confirmAction(context,
                title: 'Leave ${server?.name ?? 'server'}?',
                body: 'You will need a new invite to return.',
                confirmLabel: 'Leave server',
                danger: true);
            if (!confirmed) return;
            try {
              await state.client.leaveServer(widget.serverId);
              state.clearServer(widget.serverId);
              state.servers = state.servers
                  .where((entry) => entry.id != widget.serverId)
                  .toList();
              if (context.mounted) Navigator.of(context).maybePop();
            } catch (failure) {
              if (context.mounted) showAppToast(context, failure.toString());
            }
          },
          icon: const Icon(Icons.logout_rounded, size: 15),
          label: const Text('Leave server'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.danger,
            side: BorderSide(color: c.danger.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: context.c.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.label(9.5,
                      color: context.c.muted, weight: FontWeight.w600)),
              const SizedBox(height: 3),
              SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(22),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style:
                              context.display(17, weight: FontWeight.w600)))),
            ],
          ),
        ),
      );
}

// -----------------------------------------------------------------------------
// Roles
// -----------------------------------------------------------------------------

class _RolesTab extends StatefulWidget {
  const _RolesTab({required this.serverId});

  final String serverId;

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    setState(() => _loading = true);
    try {
      await state.loadRoles(widget.serverId, force: true);
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final state = FlackleScope.read(context);
    await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AppTextEntryDialog<bool>(
            title: 'Create role',
            label: 'Role name',
            initialValue: 'New role',
            confirmLabel: 'Create role',
            onSubmit: (name) async {
              await state.client.batchRoles(widget.serverId, {
                'creates': [
                  {'name': name, 'permissions': '0'}
                ],
              });
              if (mounted) await _load();
              return true;
            }));
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final roles = List<Role>.of(state.roles[widget.serverId] ?? const <Role>[])
      ..sort((a, b) => b.position.compareTo(a.position));
    final canManage = Permission.has(
      state.serverPermissions[widget.serverId],
      Permission.manageRoles,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Roles', style: context.display(18, weight: FontWeight.w600)),
            if (canManage)
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New role'),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Roles are ordered from highest to lowest. Every member has @everyone.',
          style: context.label(11.5, color: c.muted, height: 1.5),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: LoadingPane())
        else if (_error != null)
          ErrorPane(message: _error!, onRetry: _load)
        else ...[
          const SizedBox(height: 10),
          for (final role in roles)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: parseHexColor(role.color) ?? c.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Row(
                    children: [
                      if (role.iconEmoji != null) ...[
                        EmojiGlyph(role.iconEmoji!, size: 13),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(role.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      if (role.isEveryone)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Tag('EVERYONE', small: true),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${role.memberCount ?? 0} members · ${Permission.list(role.permissions).length} permissions'
                    '${role.hoist ? ' · shown separately' : ''}',
                    style: TextStyle(fontSize: 10, color: c.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 17),
                  onTap: canManage && !role.isEveryone
                      ? () => _editRole(role)
                      : null,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _editRole(Role role) async {
    final state = FlackleScope.read(context);
    final name = TextEditingController(text: role.name);
    final iconEmoji = ValueNotifier<String?>(role.iconEmoji);
    final color = ValueNotifier<String?>(role.color);
    var hoist = role.hoist;
    var mentionable = role.mentionable;
    final permissions = <String>{
      ...Permission.list(role.permissions),
    };
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(role.name),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  enabled: !saving,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Role name'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: iconEmoji,
                      builder: (context, value, _) => OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final emoji = await showEmojiPicker(context,
                                    title: 'Role icon');
                                if (emoji != null) iconEmoji.value = emoji;
                              },
                        icon: value == null
                            ? const Icon(Icons.add_reaction_outlined, size: 15)
                            : EmojiGlyph(value, size: 15),
                        label:
                            Text(value == null ? 'Role emoji' : 'Change emoji'),
                      ),
                    ),
                    ValueListenableBuilder<String?>(
                      valueListenable: color,
                      builder: (context, value, _) => OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await showDialog<String>(
                                  context: context,
                                  builder: (context) => SimpleDialog(
                                    title: const Text('Role colour'),
                                    children: [
                                      for (final hex in const [
                                        '#ffffff',
                                        '#ef5252',
                                        '#e0a13d',
                                        '#9ad14b',
                                        '#2fbd9f',
                                        '#4a9be8',
                                        '#8b6ce8',
                                        '#e05ea8',
                                      ])
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(context).pop(hex),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: parseHexColor(hex),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(hex),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                                if (picked != null) color.value = picked;
                              },
                        icon: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: parseHexColor(value) ?? context.c.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: const Text('Colour'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Display separately',
                      style: TextStyle(fontSize: 12.5)),
                  value: hoist,
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(() => hoist = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow anyone to @mention',
                      style: TextStyle(fontSize: 12.5)),
                  value: mentionable,
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(() => mentionable = value),
                ),
                const Divider(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in Permission.bits.entries)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          Permission.labels[entry.key] ?? entry.key,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        value: permissions.contains(entry.key),
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() {
                                  if (value == true) {
                                    permissions.add(entry.key);
                                  } else {
                                    permissions.remove(entry.key);
                                  }
                                }),
                      ),
                  ],
                ),
                const SectionLabel('Danger zone'),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final confirmed = await confirmAction(context,
                              title: 'Delete ${role.name}?',
                              body: 'Members keep their other roles.',
                              confirmLabel: 'Delete',
                              danger: true);
                          if (!confirmed) return;
                          try {
                            await state.client.batchRoles(widget.serverId, {
                              'deletes': [
                                {'id': role.id}
                              ]
                            });
                            if (context.mounted) Navigator.of(context).pop();
                            await _load();
                          } catch (failure) {
                            if (context.mounted)
                              showAppToast(context, failure.toString());
                          }
                        },
                  child: Text('Delete role',
                      style: TextStyle(color: context.c.danger)),
                ),
                if (saveError != null) InlineNotice(saveError!),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        setDialogState(() => saveError = 'Enter a role name.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        saveError = null;
                      });
                      var bits = BigInt.zero;
                      for (final name in permissions) {
                        bits |= BigInt.from(Permission.bits[name] ?? 0);
                      }
                      try {
                        await state.client.batchRoles(widget.serverId, {
                          'updates': [
                            {
                              'id': role.id,
                              'name': name.text.trim(),
                              'permissions': bits.toString(),
                              'color': color.value,
                              'hoist': hoist,
                              'mentionable': mentionable,
                              'icon_emoji': iconEmoji.value,
                              if (iconEmoji.value == null) 'clear_icon': true,
                              if (role.updatedAt != null)
                                'expected_updated_at': role.updatedAt,
                            }
                          ],
                        });
                        if (context.mounted) Navigator.of(context).pop();
                        await _load();
                      } catch (failure) {
                        if (context.mounted)
                          setDialogState(() => saveError = failure.toString());
                      } finally {
                        if (context.mounted)
                          setDialogState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save role'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    iconEmoji.dispose();
    color.dispose();
  }
}

// -----------------------------------------------------------------------------
// Members
// -----------------------------------------------------------------------------

class _MembersTab extends StatefulWidget {
  const _MembersTab({required this.serverId});

  final String serverId;

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    setState(() => _loading = true);
    try {
      await state.loadMembers(widget.serverId, force: true);
      await state.loadRoles(widget.serverId, force: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editMember(Member member) async {
    final state = FlackleScope.read(context);
    final roles = state.roles[widget.serverId] ?? const <Role>[];
    final selected = <String>{...member.roleIds};
    final canManageRoles = Permission.has(
      state.serverPermissions[widget.serverId],
      Permission.manageRoles,
    );
    final canKick = Permission.has(
        state.serverPermissions[widget.serverId], Permission.kickMembers);
    final canBan = Permission.has(
        state.serverPermissions[widget.serverId], Permission.banMembers);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppAvatar(
                        url: member.user.avatarUrl,
                        name: member.displayName,
                        size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.displayName,
                              style:
                                  context.display(16, weight: FontWeight.w600)),
                          Text(member.user.handle,
                              style: context.label(11, color: context.c.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Roles',
                    style: context.label(11,
                        weight: FontWeight.w700, color: context.c.muted)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final role
                          in roles.where((role) => !role.isEveryone))
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          enabled: canManageRoles,
                          title: Text(role.name,
                              style: const TextStyle(fontSize: 12)),
                          value: selected.contains(role.id),
                          onChanged: (value) => setSheetState(() {
                            if (value == true) {
                              selected.add(role.id);
                            } else {
                              selected.remove(role.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                if (canManageRoles)
                  FilledButton(
                    onPressed: () async {
                      final add =
                          selected.difference(member.roleIds.toSet()).toList();
                      final remove =
                          member.roleIds.toSet().difference(selected).toList();
                      try {
                        await state.client.setMemberRoles(
                            widget.serverId, member.id, add, remove);
                        if (context.mounted) Navigator.of(context).pop();
                        await _load();
                      } catch (failure) {
                        if (context.mounted)
                          showAppToast(context, failure.toString());
                      }
                    },
                    child: const Text('Save roles'),
                  ),
                if (canKick || canBan) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (canKick)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final confirmed = await confirmAction(context,
                                  title: 'Kick ${member.displayName}?',
                                  confirmLabel: 'Kick',
                                  danger: true);
                              if (!confirmed) return;
                              try {
                                await state.client
                                    .kickMember(widget.serverId, member.id);
                                if (context.mounted)
                                  Navigator.of(context).pop();
                                await _load();
                              } catch (failure) {
                                if (context.mounted) {
                                  showAppToast(context, failure.toString());
                                }
                              }
                            },
                            child: const Text('Kick'),
                          ),
                        ),
                      if (canKick && canBan) const SizedBox(width: 8),
                      if (canBan)
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final confirmed = await confirmAction(context,
                                  title: 'Ban ${member.displayName}?',
                                  body:
                                      'They will be removed and blocked from rejoining.',
                                  confirmLabel: 'Ban',
                                  danger: true);
                              if (!confirmed) return;
                              try {
                                await state.client
                                    .banMember(widget.serverId, member.id);
                                if (context.mounted)
                                  Navigator.of(context).pop();
                                await _load();
                              } catch (failure) {
                                if (context.mounted) {
                                  showAppToast(context, failure.toString());
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: context.c.danger),
                            child: const Text('Ban'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final members = state
        .membersFor(widget.serverId)
        .where((member) =>
            _query.isEmpty ||
            member.displayName.toLowerCase().contains(_query.toLowerCase()) ||
            member.user.username.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Members',
                style: context.display(18, weight: FontWeight.w600)),
            const SizedBox(width: 7),
            Tag('${state.membersFor(widget.serverId).length}', small: true),
            const Spacer(),
            IconButton(
              onPressed: _load,
              tooltip: 'Refresh members',
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Search members',
            prefixIcon: Icon(Icons.search_rounded, size: 17),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: LoadingPane())
        else
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Material(
                color: c.panel,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _editMember(member),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(
                      children: [
                        AppAvatar(
                            url: member.user.avatarUrl,
                            name: member.displayName,
                            size: 34),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(member.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.label(12.5,
                                            weight: FontWeight.w600)),
                                  ),
                                  if (member.isOwner) ...[
                                    const SizedBox(width: 4),
                                    const AppIcon('crown',
                                        size: 11, color: Color(0xFFE0A13D)),
                                  ],
                                ],
                              ),
                              Text(member.user.handle,
                                  style: context.label(10, color: c.muted)),
                            ],
                          ),
                        ),
                        Text(
                          member.roleIds.length == 0
                              ? '@everyone'
                              : '${member.roleIds.length} roles',
                          style: context.label(10, color: c.muted),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Invites
// -----------------------------------------------------------------------------

class _InvitesTab extends StatefulWidget {
  const _InvitesTab({required this.serverId});

  final String serverId;

  @override
  State<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends State<_InvitesTab> {
  List<Invite> _invites = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    setState(() => _loading = true);
    try {
      final invites = await state.client.fetchServerInvites(widget.serverId);
      if (mounted)
        setState(() {
          _invites = invites;
          _error = null;
        });
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final state = FlackleScope.read(context);
    try {
      final invite =
          await state.client.createServerInvite(widget.serverId, const {});
      await Clipboard.setData(ClipboardData(text: invite.displayUrl));
      if (mounted) showAppToast(context, 'Invite copied: ${invite.displayUrl}');
      await _load();
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Invites',
                style: context.display(18, weight: FontWeight.w600)),
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_link_rounded, size: 16),
              label: const Text('Create invite'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
            'Invites grant access to this server until they expire or are revoked.',
            style: context.label(11.5, color: c.muted, height: 1.5)),
        const SizedBox(height: 12),
        if (_loading)
          const LoadingPane()
        else if (_error != null)
          ErrorPane(message: _error!, onRetry: _load)
        else if (_invites.isEmpty)
          Text('No active invites.', style: context.label(12, color: c.muted))
        else
          for (final invite in _invites)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  AppIcon('link', size: 16, color: c.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invite.code,
                            style:
                                context.label(12.5, weight: FontWeight.w600)),
                        Text(
                          '${invite.uses} uses'
                          '${invite.maxUses == null ? '' : ' of ${invite.maxUses}'}'
                          '${invite.creatorUsername == null ? '' : ' · by ${invite.creatorUsername}'}',
                          style: context.label(10, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: invite.displayUrl));
                      if (context.mounted)
                        showAppToast(context, 'Invite copied.');
                    },
                    tooltip: 'Copy',
                    icon: const AppIcon('copy', size: 15),
                  ),
                  IconButton(
                    onPressed: () async {
                      final confirmed = await confirmAction(context,
                          title: 'Revoke ${invite.code}?',
                          confirmLabel: 'Revoke',
                          danger: true);
                      if (!confirmed) return;
                      try {
                        await FlackleScope.read(context)
                            .client
                            .deleteServerInvite(widget.serverId, invite.code);
                        await _load();
                      } catch (failure) {
                        if (context.mounted)
                          showAppToast(context, failure.toString());
                      }
                    },
                    tooltip: 'Revoke',
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 17, color: c.danger),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Bans
// -----------------------------------------------------------------------------

class _BansTab extends StatefulWidget {
  const _BansTab({required this.serverId});

  final String serverId;

  @override
  State<_BansTab> createState() => _BansTabState();
}

class _BansTabState extends State<_BansTab> {
  List<ServerBan> _bans = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    setState(() => _loading = true);
    try {
      final bans = await state.client.fetchBans(widget.serverId);
      if (mounted)
        setState(() {
          _bans = bans;
          _error = null;
        });
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBan() async {
    final state = FlackleScope.read(context);
    final userId = TextEditingController();
    final reason = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban a user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userId,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.c.danger),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
    if (added == true && userId.text.trim().isNotEmpty) {
      try {
        await state.client.banMember(widget.serverId, userId.text.trim(),
            reason: reason.text.trim().isEmpty ? null : reason.text.trim());
        await _load();
      } catch (failure) {
        if (mounted) showAppToast(context, failure.toString());
      }
    }
    userId.dispose();
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Bans', style: context.display(18, weight: FontWeight.w600)),
            FilledButton.icon(
              onPressed: _addBan,
              icon: const Icon(Icons.person_off_outlined, size: 16),
              label: const Text('Ban user'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text('Banned members cannot rejoin until unbanned.',
            style: context.label(11.5, color: c.muted)),
        const SizedBox(height: 12),
        if (_loading)
          const LoadingPane()
        else if (_error != null)
          ErrorPane(message: _error!, onRetry: _load)
        else if (_bans.isEmpty)
          Text('No bans on this server.',
              style: context.label(12, color: c.muted))
        else
          for (final ban in _bans)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  AppAvatar(
                    url: ban.user?.avatarUrl,
                    name: ban.user?.name ?? ban.userId,
                    size: 32,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ban.user?.name ?? ban.userId,
                            style:
                                context.label(12.5, weight: FontWeight.w600)),
                        Text(
                          [
                            if (ban.reason?.isNotEmpty == true) ban.reason!,
                            if (ban.createdAt != null)
                              relativeTime(ban.createdAt),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(10, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await FlackleScope.read(context)
                            .client
                            .unbanMember(widget.serverId, ban.userId);
                        await _load();
                      } catch (failure) {
                        if (context.mounted)
                          showAppToast(context, failure.toString());
                      }
                    },
                    child: const Text('Unban'),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Audit log
// -----------------------------------------------------------------------------

class _AuditTab extends StatefulWidget {
  const _AuditTab({required this.serverId});

  final String serverId;

  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  List<AuditEntry> _entries = const [];
  String? _before;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    final state = FlackleScope.read(context);
    setState(() => _loading = true);
    try {
      final page = await state.client.fetchAuditLog(
        widget.serverId,
        before: append ? _before : null,
      );
      final entries = asList(page['entries'])
          .whereType<Map>()
          .map((value) => AuditEntry.fromJson(asMap(value)))
          .toList();
      if (mounted) {
        setState(() {
          _entries = append ? [..._entries, ...entries] : entries;
          _hasMore = asBool(page['has_more']);
          _before = entries.isEmpty ? null : entries.last.id;
          _error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Audit log',
                style: context.display(18, weight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              onPressed: () => _load(),
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
        Text('Every moderation and configuration change on this server.',
            style: context.label(11.5, color: c.muted)),
        const SizedBox(height: 12),
        if (_loading && _entries.isEmpty)
          const LoadingPane()
        else if (_error != null)
          ErrorPane(message: _error!, onRetry: () => _load())
        else if (_entries.isEmpty)
          Text('No audit entries yet.',
              style: context.label(12, color: c.muted))
        else ...[
          for (final entry in _entries)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        url: entry.actor?.avatarUrl,
                        name: entry.actor?.name ?? 'System',
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entry.actor?.name ?? 'System'} · ${entry.actionType.replaceAll('_', ' ')}',
                          style: context.label(11.5, weight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        entry.createdAt == null
                            ? ''
                            : relativeTime(entry.createdAt),
                        style: context.label(9.5, color: c.muted),
                      ),
                    ],
                  ),
                  if (entry.changes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 34),
                      child: Text(
                        entry.changes
                            .map((change) =>
                                '${change.key ?? 'value'}: ${change.oldValue ?? ' - '} -> ${change.newValue ?? ' - '}')
                            .join('\n'),
                        style: context.label(10, color: c.muted, height: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: () => _load(append: true),
                child: const Text('Load more'),
              ),
            ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Lifts
// -----------------------------------------------------------------------------

class _LiftsTab extends StatefulWidget {
  const _LiftsTab({required this.serverId});

  final String serverId;

  @override
  State<_LiftsTab> createState() => _LiftsTabState();
}

class _LiftsTabState extends State<_LiftsTab> {
  LiftsInfo? _info;
  List<User> _supporters = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = FlackleScope.read(context);
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        state.client.fetchLifts(widget.serverId),
        state.client
            .fetchLiftSupporters(widget.serverId)
            .catchError((Object _) => <User>[]),
      ]);
      if (mounted) {
        setState(() {
          _info = results[0] as LiftsInfo;
          _supporters = results[1] as List<User>;
          _error = null;
        });
      }
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final info = _info;
    if (_loading) return const LoadingPane();
    if (_error != null) return ErrorPane(message: _error!, onRetry: _load);
    if (info == null) {
      return Text('Lifts are not available for this server.',
          style: context.label(12, color: c.muted));
    }
    final progress = info.nextLevelAt == 0
        ? 0.0
        : (info.count / info.nextLevelAt).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lifts', style: context.display(18, weight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(
          'Lifts raise the server\'s upload and retention limits. Anyone can support the server.',
          style: context.label(11.5, color: c.muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const AppIcon('gift', size: 18, color: Color(0xFFE0A13D)),
                    const SizedBox(width: 8),
                    Text('Level ${info.level}',
                        style: context.display(17, weight: FontWeight.w600)),
                  ]),
                  Text('${info.count} / ${info.nextLevelAt}',
                      style: context.label(11, color: c.muted)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: c.panel3,
                ),
              ),
              const SizedBox(height: 12),
              _row(context, 'Max upload', formatSize(info.maxUploadBytes)),
              _row(context, 'Saved media budget',
                  formatSize(info.savedBudgetBytes)),
              _row(context, 'Retention multiplier',
                  '${info.retentionMultiplier.toStringAsFixed(1)}x'),
            ],
          ),
        ),
        const SectionLabel('Supporters'),
        if (_supporters.isEmpty)
          Text('No supporters yet.', style: context.label(11.5, color: c.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final user in _supporters)
                Chip(
                  avatar:
                      AppAvatar(url: user.avatarUrl, name: user.name, size: 20),
                  label: Text(user.name),
                ),
            ],
          ),
        if (info.levels.isNotEmpty) ...[
          const SectionLabel('Level thresholds'),
          for (final level in info.levels)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text('Level ${level['level'] ?? '?'}',
                        style: context.label(11, weight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(
                      '${level['lifts_needed'] ?? '?'} lifts · '
                      '${formatSize(level['max_upload_bytes'] is num ? (level['max_upload_bytes'] as num).toInt() : null)} uploads',
                      style: context.label(10.5, color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Expanded(
              child:
                  Text(label, style: context.label(11, color: context.c.muted)),
            ),
            Text(value, style: context.label(11, weight: FontWeight.w600)),
          ],
        ),
      );
}

Color? parseHexColor(String? hex) {
  if (hex == null || !hex.startsWith('#')) return null;
  final value = hex.substring(1);
  final normalized = value.length == 3
      ? value.split('').map((char) => '$char$char').join()
      : value.padRight(6, '0').substring(0, 6);
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}
