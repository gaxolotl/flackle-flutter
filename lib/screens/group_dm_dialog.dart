import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';

/// Lets the user pick friends and create a group conversation.
Future<Conversation?> showCreateGroupDm(BuildContext context) async {
  final state = FlackleScope.read(context);
  if (state.friends.isEmpty) {
    showAppToast(context, 'Add friends before creating a group.');
    return null;
  }
  return showDialog<Conversation>(
    context: context,
    builder: (context) => _GroupDmDialog(state: state),
  );
}

class _GroupDmDialog extends StatefulWidget {
  const _GroupDmDialog({required this.state});

  final AppState state;

  @override
  State<_GroupDmDialog> createState() => _GroupDmDialogState();
}

class _GroupDmDialogState extends State<_GroupDmDialog> {
  final _name = TextEditingController();
  final _selected = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selected.length < 2) {
      setState(() => _error = 'Pick at least two friends for a group.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final conversation = await widget.state.client
          .createGroupDM(_selected.toList(), name: _name.text);
      await widget.state.refreshConversations();
      if (mounted) Navigator.of(context).pop(conversation);
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final friends = widget.state.friends;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.group_add_outlined, size: 19, color: c.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('New group DM',
                        style: context.display(18, weight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _name,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Group name (optional)',
                  hintText: 'Weekend plans',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Row(
                children: [
                  Text('Pick friends',
                      style: context.label(11,
                          weight: FontWeight.w600, color: c.muted)),
                  const Spacer(),
                  Text('${_selected.length} selected',
                      style: context.label(10.5, color: c.muted)),
                ],
              ),
            ),
            Flexible(
              child: friends.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No friends to add yet.',
                          style: TextStyle(color: c.muted)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final user = friends[index];
                        final checked = _selected.contains(user.id);
                        return CheckboxListTile(
                          value: checked,
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          secondary: AppAvatar(
                            url: user.avatarUrl,
                            name: user.name,
                            size: 30,
                          ),
                          title: Text(user.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(user.handle,
                              style: TextStyle(fontSize: 10.5, color: c.muted)),
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(_error!,
                    style: TextStyle(color: c.danger, fontSize: 12)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.group_add_outlined, size: 16),
                    label: Text(_busy ? 'Creating...' : 'Create group'),
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
