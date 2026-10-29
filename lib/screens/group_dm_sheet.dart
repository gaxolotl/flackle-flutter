import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';

/// Group DM details: rename, add people and leave.
Future<void> showGroupDmSheet(
  BuildContext context,
  Conversation conversation,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.c.panel,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: _GroupDmSheet(conversation: conversation),
      ),
    ),
  );
}

class _GroupDmSheet extends StatefulWidget {
  const _GroupDmSheet({required this.conversation});

  final Conversation conversation;

  @override
  State<_GroupDmSheet> createState() => _GroupDmSheetState();
}

class _GroupDmSheetState extends State<_GroupDmSheet> {
  late Conversation _conversation = widget.conversation;
  late final TextEditingController _name =
      TextEditingController(text: widget.conversation.name ?? '');
  bool _busy = false;

  AppState get _state => FlackleScope.read(context);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final conversation =
          await _state.client.fetchConversation(_conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        if (_name.text.isEmpty && conversation.name != null) {
          _name.text = conversation.name!;
        }
      });
    } catch (_) {
      // Keep the members we already know about.
    }
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _state.client.updateConversation(_conversation.id, name: name);
      await _state.refreshConversations();
      await _reload();
      if (mounted) showAppToast(context, 'Group renamed.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPeople() async {
    final existing =
        _conversation.members.map((member) => member.user.id).toSet();
    final candidates =
        _state.friends.where((user) => !existing.contains(user.id)).toList();
    if (candidates.isEmpty) {
      showAppToast(context, 'All your friends are already in this group.');
      return;
    }
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _AddPeopleDialog(friends: candidates),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _state.client.addConversationMembers(_conversation.id, selected);
      await _state.refreshConversations();
      await _reload();
      if (mounted) showAppToast(context, 'People added to the group.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await confirmAction(
      context,
      title: 'Leave ${_conversation.titleFor(_state.me?.id ?? '')}?',
      body: 'You will stop receiving messages from this group.',
      confirmLabel: 'Leave group',
      danger: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await _state.client.leaveConversation(_conversation.id);
      await _state.removeConversation(_conversation.id);
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final myId = _state.me?.id ?? '';
    final members = _conversation.members;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                    child: Text('Group details',
                        style: context.display(17, weight: FontWeight.w600))),
                IconButton(
                  tooltip: 'Close group details',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                TextField(
                  controller: _name,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Group name',
                    hintText: _conversation.titleFor(myId),
                    suffixIcon: IconButton(
                      onPressed: _busy ? null : _saveName,
                      tooltip: 'Save name',
                      icon: const Icon(Icons.check_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text('Members (${members.length})',
                        style: context.label(11,
                            weight: FontWeight.w600, color: c.muted)),
                    TextButton.icon(
                      onPressed: _busy ? null : _addPeople,
                      icon:
                          const Icon(Icons.person_add_alt_1_outlined, size: 15),
                      label: const Text('Add people'),
                    ),
                  ],
                ),
                for (final member in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: AppAvatar(
                      url: member.user.avatarUrl,
                      name: member.user.name,
                      size: 32,
                    ),
                    title: Text(
                      member.user.id == myId
                          ? '${member.user.name} (you)'
                          : member.user.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(member.user.handle,
                        style: TextStyle(fontSize: 10.5, color: c.muted)),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _leave,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Leave group'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger.withValues(alpha: 0.35)),
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPeopleDialog extends StatefulWidget {
  const _AddPeopleDialog({required this.friends});

  final List<User> friends;

  @override
  State<_AddPeopleDialog> createState() => _AddPeopleDialogState();
}

class _AddPeopleDialogState extends State<_AddPeopleDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: const Text('Add people'),
      content: SizedBox(
        width: 380,
        height: 360,
        child: ListView.builder(
          itemCount: widget.friends.length,
          itemBuilder: (context, index) {
            final user = widget.friends[index];
            return CheckboxListTile(
              value: _selected.contains(user.id),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: AppAvatar(
                url: user.avatarUrl,
                name: user.name,
                size: 30,
              ),
              title: Text(user.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(user.handle,
                  style: TextStyle(fontSize: 10.5, color: c.muted)),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selected.add(user.id);
                } else {
                  _selected.remove(user.id);
                }
              }),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
