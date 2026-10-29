import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/icons.dart';

Future<void> openAddServer(BuildContext context) async {
  final state = FlackleScope.read(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AddServerDialog(state: state),
  );
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog({required this.state});

  final AppState state;

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final _name = TextEditingController();
  final _invite = TextEditingController();
  String _mode = 'create';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == 'create') {
        final name = _name.text.trim();
        if (name.isEmpty) {
          setState(() {
            _error = 'Give your server a name.';
            _busy = false;
          });
          return;
        }
        final result = await widget.state.client.createServer(name);
        final server = Server.fromJson(asMap(result['server']));
        widget.state.servers = [...widget.state.servers, server];
        await widget.state.loadBundle(server.id);
        final bundle = widget.state.bundles[server.id];
        await widget.state.selectServer(server.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        if (bundle != null && context.mounted) {
          showAppToast(context, '${server.name} is ready.');
        }
      } else {
        final raw = _invite.text.trim();
        if (raw.isEmpty) {
          setState(() {
            _error = 'Paste an invite link or code.';
            _busy = false;
          });
          return;
        }
        final code = raw.contains('/')
            ? raw.split('/').where((part) => part.isNotEmpty).last
            : raw;
        final result = await widget.state.client.acceptInvite(code);
        final server = result['server'] is Map
            ? Server.fromJson(asMap(result['server']))
            : null;
        final servers = await widget.state.client.fetchServers();
        widget.state.servers = servers;
        if (server != null) {
          await widget.state.loadBundle(server.id);
          await widget.state.selectServer(
            server.id,
            preferredChannelId: asStringOrNull(result['landing_channel_id']),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        if (server != null && context.mounted) {
          showAppToast(context, 'Joined ${server.name}.');
        }
      }
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const FlackleMark(size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Add a server',
                        style: context.display(19, weight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _modeButton(context, 'create', 'Create'),
                  const SizedBox(width: 6),
                  _modeButton(context, 'join', 'Join with invite'),
                ],
              ),
              const SizedBox(height: 16),
              if (_mode == 'create') ...[
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Server name',
                    hintText: 'The Cozy Corner',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A default #general channel is created for you. You can add categories, channels and roles afterwards.',
                  style: context.label(11.5, color: c.muted, height: 1.5),
                ),
              ] else ...[
                TextField(
                  controller: _invite,
                  enabled: !_busy,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Invite link or code',
                    hintText: 'https://flackle.com/invite/abc123',
                    prefixIcon: Icon(Icons.link_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste a server invite from anyone. You will land in the channel the invite points at.',
                  style: context.label(11.5, color: c.muted, height: 1.5),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                InlineNotice(_error!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _mode == 'create' ? _name : _invite,
                  builder: (context, value, _) => FilledButton(
                    onPressed:
                        _busy || value.text.trim().isEmpty ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_mode == 'create'
                            ? 'Create server'
                            : 'Join server'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(BuildContext context, String mode, String label) {
    final c = context.c;
    final selected = _mode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: _busy
            ? null
            : () => setState(() {
                  _mode = mode;
                  _error = null;
                }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accentDim : c.input,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? c.accent : c.line),
          ),
          child: Text(
            label,
            style: context.label(12,
                weight: FontWeight.w600,
                color: selected ? c.accent : c.textDim),
          ),
        ),
      ),
    );
  }
}
