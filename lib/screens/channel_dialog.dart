import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';

Future<void> openChannelCreate(
  BuildContext context,
  String serverId, {
  String? categoryId,
}) =>
    openChannelDialog(context, serverId: serverId, categoryId: categoryId);

Future<void> openChannelEdit(
  BuildContext context,
  String serverId,
  Channel channel,
) =>
    openChannelDialog(context, serverId: serverId, channel: channel);

Future<void> openChannelDialog(
  BuildContext context, {
  required String serverId,
  Channel? channel,
  String? categoryId,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ChannelDialog(
      serverId: serverId,
      channel: channel,
      categoryId: categoryId,
    ),
  );
}

Future<Category?> openCategoryCreate(BuildContext context, String serverId) {
  final state = FlackleScope.read(context);
  return showDialog<Category>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppTextEntryDialog<Category>(
          title: 'Create category',
          label: 'Category name',
          confirmLabel: 'Create category',
          onSubmit: (name) async {
            final category = await state.client.createCategory(serverId, name);
            await state.reloadBundle(serverId);
            return category;
          }));
}

Future<void> openCategoryEdit(
    BuildContext context, String serverId, Category category) async {
  final state = FlackleScope.read(context);
  await showDialog<Category>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppTextEntryDialog<Category>(
          title: 'Edit category',
          label: 'Category name',
          initialValue: category.name,
          confirmLabel: 'Save changes',
          onSubmit: (name) async {
            final updated =
                await state.client.updateCategory(serverId, category.id, name);
            await state.reloadBundle(serverId);
            return updated;
          }));
}

class _ChannelDialog extends StatefulWidget {
  const _ChannelDialog({
    required this.serverId,
    this.channel,
    this.categoryId,
  });

  final String serverId;
  final Channel? channel;
  final String? categoryId;

  @override
  State<_ChannelDialog> createState() => _ChannelDialogState();
}

class _ChannelDialogState extends State<_ChannelDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.channel?.name ?? '');
  late final TextEditingController _topic =
      TextEditingController(text: widget.channel?.topic ?? '');
  late final TextEditingController _slowmode = TextEditingController(
      text: widget.channel?.slowmodeSeconds?.toString() ?? '0');
  late String _type = widget.channel?.type ?? 'text';
  late String? _categoryId = widget.channel?.categoryId ?? widget.categoryId;
  late String? _color = widget.channel?.iconColor;
  late String? _icon = widget.channel?.icon;
  bool _busy = false;
  String? _error;

  bool get editing => widget.channel != null;

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    _slowmode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = FlackleScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the channel a name.');
      return;
    }
    final slowmode = int.tryParse(_slowmode.text.trim());
    if (slowmode == null || slowmode < 0 || slowmode > 21600) {
      setState(() => _error = 'Enter slow mode between 0 and 21600 seconds.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (editing) {
        await state.client.updateChannel(widget.serverId, widget.channel!.id, {
          'name': name,
          'topic': _topic.text.trim(),
          'slowmode_seconds': slowmode.clamp(0, 21600).toInt(),
          'category_id': _categoryId,
          'icon': _icon,
          if (_color != null) 'icon_color': _color,
        });
      } else {
        await state.client.createChannel(widget.serverId, {
          'name': name,
          'type': _type,
          'category_id': _categoryId,
          if (_icon != null) 'icon': _icon,
          if (_color != null) 'icon_color': _color,
          if (_topic.text.trim().isNotEmpty) 'topic': _topic.text.trim(),
          'slowmode_seconds': slowmode.clamp(0, 21600).toInt(),
        });
      }
      await state.reloadBundle(widget.serverId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (context.mounted) {
        showAppToast(
            context, editing ? 'Channel updated.' : 'Channel created.');
      }
    } catch (failure) {
      if (mounted) setState(() => _error = failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final state = FlackleScope.read(context);
    final confirmed = await confirmAction(context,
        title: 'Delete #${widget.channel!.name}?',
        body: 'All messages in this channel will be removed for everyone.',
        confirmLabel: 'Delete channel',
        danger: true);
    if (!confirmed) return;
    try {
      await state.client.deleteChannel(widget.serverId, widget.channel!.id);
      await state.reloadBundle(widget.serverId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (context.mounted && state.active?.channelId == widget.channel!.id) {
        final bundle = state.bundles[widget.serverId];
        final next = bundle?.channels.firstWhere(
          (channel) => channel.isText,
          orElse: () => bundle.channels.first,
        );
        if (next != null) {
          await state.selectChannel(widget.serverId, next);
        }
      }
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final c = context.c;
    final categories = state.categoriesFor(widget.serverId);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(editing ? 'pencil' : 'plus',
                      size: 17, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      editing ? 'Edit channel' : 'Create channel',
                      style: context.display(19, weight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!editing) ...[
                Text('Channel type',
                    style: context.label(11,
                        weight: FontWeight.w600, color: c.muted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final option in const [
                      ('text', 'Text', 'hash'),
                      ('voice', 'Voice', 'speaker'),
                      ('stats', 'Stats', 'chart'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: _busy
                                ? null
                                : () => setState(() => _type = option.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color:
                                    _type == option.$1 ? c.accentDim : c.input,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: _type == option.$1 ? c.accent : c.line,
                                ),
                              ),
                              child: Column(
                                children: [
                                  AppIcon(option.$3,
                                      size: 16,
                                      color: _type == option.$1
                                          ? c.accent
                                          : c.muted),
                                  const SizedBox(height: 4),
                                  Text(option.$2,
                                      style: context.label(10.5,
                                          weight: FontWeight.w600,
                                          color: _type == option.$1
                                              ? c.accent
                                              : c.textDim)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Channel name',
                  hintText: 'e.g. design',
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _topic,
                enabled: !_busy,
                maxLines: 2,
                maxLength: 1024,
                decoration: const InputDecoration(
                  labelText: 'Topic (optional)',
                  hintText: 'What is this channel for?',
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No category')),
                  for (final category in categories)
                    DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _categoryId = value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final created = await openCategoryCreate(
                              context, widget.serverId);
                          if (created != null && mounted) {
                            setState(() => _categoryId = created.id);
                          }
                        },
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('New category'),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _slowmode,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Slow mode (seconds)',
                  helperText: '0 disables slow mode. Maximum 21600.',
                ),
              ),
              const SizedBox(height: 14),
              Text('Channel icon',
                  style: context.label(11,
                      weight: FontWeight.w600, color: c.muted)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.input,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.line),
                    ),
                    child: ChannelGlyph(
                      name: _icon,
                      color: _color,
                      type: _type,
                      size: 20,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final emoji = await showEmojiPicker(context,
                                title: 'Channel icon');
                            if (emoji != null && mounted) {
                              setState(() => _icon = emoji);
                            }
                          },
                    icon: const Icon(Icons.emoji_emotions_outlined, size: 15),
                    label:
                        Text(_icon == null ? 'Choose emoji' : 'Change emoji'),
                  ),
                  if (_icon != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed:
                          _busy ? null : () => setState(() => _icon = null),
                      tooltip: 'Clear icon',
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text('Icon tint',
                  style: context.label(11,
                      weight: FontWeight.w600, color: c.muted)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                children: [
                  _colorDot(context, null),
                  for (final color in const [
                    '#95a5a6',
                    '#8b6ce8',
                    '#2fbd9f',
                    '#4a9be8',
                    '#e05ea8',
                    '#e0a13d',
                    '#ef5252',
                  ])
                    _colorDot(context, color),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InlineNotice(_error!),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 8,
                children: [
                  if (editing)
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const AppIcon('trash',
                          size: 15, color: Color(0xFFEF5252)),
                      label: const Text('Delete',
                          style: TextStyle(color: Color(0xFFEF5252))),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, value, _) => FilledButton(
                      onPressed:
                          _busy || value.text.trim().isEmpty ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(editing ? 'Save changes' : 'Create channel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorDot(BuildContext context, String? hex) {
    final c = context.c;
    final selected = _color == hex;
    final color = hex == null
        ? c.muted
        : Color(int.parse('FF${hex.substring(1)}', radix: 16));
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: _busy ? null : () => setState(() => _color = hex),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: hex == null ? c.input : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.text : c.lineStrong,
            width: selected ? 2 : 1,
          ),
        ),
        child: hex == null
            ? Icon(Icons.block_rounded, size: 13, color: c.muted)
            : null,
      ),
    );
  }
}
