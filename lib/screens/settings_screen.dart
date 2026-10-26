import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/prefs.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';
import 'profile_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _tab = widget.initialTab;

  static const _tabs = [
    ('user', 'Account'),
    ('palette', 'Appearance'),
    ('smile', 'Chat'),
    ('bell', 'Notifications'),
    ('shield', 'Security'),
    ('sparkles', 'About'),
  ];

  AppState get state => FlackleScope.read(context);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= 860;
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: context.display(17, weight: FontWeight.w600)),
        leading: IconButton(
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
                        _navTile(context, index),
                    ],
                  ),
                ),
                VerticalDivider(width: 1, color: c.line),
                Expanded(child: _body(context)),
              ],
            )
          : Column(
              children: [
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    children: [
                      for (var index = 0; index < _tabs.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: _tab == index,
                            showCheckmark: false,
                            avatar: AppIcon(_tabs[index].$1,
                                size: 14,
                                color: _tab == index ? c.accent : c.muted),
                            label: Text(_tabs[index].$2),
                            onSelected: (_) => setState(() => _tab = index),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: c.line),
                Expanded(child: _body(context)),
              ],
            ),
    );
  }

  Widget _navTile(BuildContext context, int index) {
    final c = context.c;
    final selected = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? c.active : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              AppIcon(_tabs[index].$1,
                  size: 16, color: selected ? c.accent : c.muted),
              const SizedBox(width: 9),
              Text(_tabs[index].$2,
                  style: context.label(12.5,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? c.text : c.textDim)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final child = switch (_tab) {
      0 => const _AccountTab(),
      1 => const _AppearanceTab(),
      2 => const _ChatTab(),
      3 => const _NotificationsTab(),
      4 => const _SecurityTab(),
      _ => const _AboutTab(),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Account
// -----------------------------------------------------------------------------

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final me = state.me;
    final c = context.c;
    final currentStatus =
        me == null ? 'online' : state.presences[me.id] ?? me.status ?? 'online';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: me == null ? null : () => showProfile(context, user: me),
              child: AppAvatar(
                  url: me?.avatarUrl, name: me?.name ?? 'You', size: 58),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me?.name ?? 'You',
                      style: context.display(20, weight: FontWeight.w600)),
                  Text(me?.handle ?? '',
                      style: context.label(12, color: c.muted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Tag(state.isConnected ? 'LIVE' : 'OFFLINE',
                          color: state.isConnected ? c.green : c.yellow,
                          small: true),
                      if (me?.isAdmin == true) ...[
                        const SizedBox(width: 5),
                        const Tag('ADMIN',
                            color: Color(0xFFE0A13D), small: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ProfileEditorScreen()),
              ),
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        const SectionLabel('Account details'),
        _kv(context, 'Email', me?.email ?? 'Hidden'),
        _kv(context, 'Username', me?.username ?? ''),
        _kv(context, 'User ID', me?.id ?? ''),
        const SectionLabel('Presence'),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final entry in const [
              ('online', 'Online'),
              ('dnd', 'Do not disturb'),
              ('invisible', 'Invisible'),
            ])
              ChoiceChip(
                selected: currentStatus == entry.$1,
                showCheckmark: false,
                avatar: Icon(
                  entry.$1 == 'online'
                      ? Icons.circle
                      : entry.$1 == 'dnd'
                          ? Icons.do_not_disturb_on_outlined
                          : Icons.circle_outlined,
                  size: 12,
                  color: entry.$1 == 'online'
                      ? c.green
                      : entry.$1 == 'dnd'
                          ? c.danger
                          : c.muted,
                ),
                label: Text(entry.$2),
                onSelected: (_) async {
                  try {
                    await state.setMyStatus(entry.$1);
                    if (context.mounted)
                      showAppToast(context, 'Status set to ${entry.$2}.');
                  } catch (failure) {
                    if (context.mounted)
                      showAppToast(context, failure.toString());
                  }
                },
              ),
          ],
        ),
        const SectionLabel('Typing indicator'),
        Text(
          'Flackle lets you choose the text people see while you type.',
          style: context.label(12, color: c.muted, height: 1.5),
        ),
        const SizedBox(height: 10),
        _TypingIndicatorEditor(state: state),
        const SectionLabel('Session'),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await confirmAction(context,
                title: 'Sign out?',
                body: 'You can sign back in at any time.',
                confirmLabel: 'Sign out',
                danger: true);
            if (!confirmed) return;
            await state.logout();
            if (context.mounted) Navigator.of(context).maybePop();
          },
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.danger,
            side: BorderSide(color: c.danger.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: context.label(11,
                      weight: FontWeight.w600, color: context.c.muted)),
            ),
            Expanded(
              child: SelectableText(value,
                  style: context.label(12.5, color: context.c.textDim)),
            ),
          ],
        ),
      );
}

class _TypingIndicatorEditor extends StatefulWidget {
  const _TypingIndicatorEditor({required this.state});

  final AppState state;

  @override
  State<_TypingIndicatorEditor> createState() => _TypingIndicatorEditorState();
}

class _TypingIndicatorEditorState extends State<_TypingIndicatorEditor> {
  late final TextEditingController _text =
      TextEditingController(text: widget.state.me?.typingIndicatorText ?? '');
  late bool _enabled = widget.state.me?.typingIndicatorEnabled ?? false;
  late String _style = widget.state.me?.typingIndicatorStyle ??
      (widget.state.me?.typingIndicatorEmojis?.isNotEmpty == true
          ? 'emojis'
          : 'dots');
  late final List<String> _emojis =
      (widget.state.me?.typingIndicatorEmojis ?? const <String>[])
          .take(3)
          .toList();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addEmoji() async {
    if (_emojis.length >= 3) {
      showAppToast(context, 'You can add up to 3 emojis.');
      return;
    }
    final emoji = await showEmojiPicker(context, title: 'Typing indicator');
    if (emoji == null || !mounted) return;
    setState(() => _emojis.add(emoji));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.state.client.updateTypingIndicator(
        enabled: _enabled,
        text: _text.text.trim().isEmpty ? null : _text.text.trim(),
        style: _style,
        emojis: _emojis,
      );
      await widget.state.refreshMe();
      if (mounted) {
        showAppToast(context, 'Typing indicator updated.');
      }
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title:
              const Text('Custom typing text', style: TextStyle(fontSize: 13)),
          subtitle: Text(
            'Replace the default "is typing..." line with your own phrase.',
            style: TextStyle(fontSize: 11, color: context.c.muted),
          ),
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        if (_enabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _text,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Typing text',
                hintText: 'is overthinking it...',
              ),
            ),
          ),
        if (_enabled) ...[
          Text('Indicator style',
              style: context.label(11.5,
                  weight: FontWeight.w600, color: context.c.muted)),
          const SizedBox(height: 7),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'dots', label: Text('Typing dots')),
              ButtonSegment(value: 'emojis', label: Text('Custom emojis')),
            ],
            selected: {_style},
            showSelectedIcon: false,
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() => _style = selection.first),
          ),
          const SizedBox(height: 12),
        ],
        if (_enabled && _style == 'emojis') ...[
          Text('Typing emojis (up to 3)',
              style: context.label(11.5,
                  weight: FontWeight.w600, color: context.c.muted)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final emoji in _emojis)
                InputChip(
                  label: EmojiGlyph(emoji, size: 17),
                  onDeleted: () => setState(() => _emojis.remove(emoji)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 13),
                ),
              if (_emojis.length < 3)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Add emoji'),
                  onPressed: _busy ? null : _addEmoji,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
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
                : const Text('Save typing indicator'),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Appearance
// -----------------------------------------------------------------------------

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final prefs = state.prefs;
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme', style: context.display(18, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final entry in const [
              ('dark', 'Dark', Icons.dark_mode_outlined),
              ('light', 'Light', Icons.light_mode_outlined),
              ('system', 'System', Icons.brightness_auto_outlined),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => prefs.setTheme(entry.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: prefs.theme == entry.$1 ? c.accentDim : c.panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: prefs.theme == entry.$1 ? c.accent : c.line),
                      ),
                      child: Column(
                        children: [
                          Icon(entry.$3,
                              size: 20,
                              color:
                                  prefs.theme == entry.$1 ? c.accent : c.muted),
                          const SizedBox(height: 5),
                          Text(entry.$2,
                              style: context.label(11.5,
                                  weight: FontWeight.w600,
                                  color: prefs.theme == entry.$1
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
        const SectionLabel('Accent'),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final choice in accentChoices)
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => prefs.setAccent(choice.id),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: choice.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: prefs.accent == choice.id
                          ? c.text
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: prefs.accent == choice.id
                      ? const Icon(Icons.check_rounded,
                          size: 17, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        const SectionLabel('Density'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'cozy', label: Text('Cozy')),
            ButtonSegment(value: 'compact', label: Text('Compact')),
          ],
          selected: {prefs.density},
          onSelectionChanged: (value) => prefs.setDensity(value.first),
        ),
        const SectionLabel('Message text size'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'small', label: Text('Small')),
            ButtonSegment(value: 'normal', label: Text('Default')),
            ButtonSegment(value: 'large', label: Text('Large')),
          ],
          selected: {prefs.textSize},
          onSelectionChanged: (value) => prefs.setTextSize(value.first),
        ),
        const SectionLabel('Layout'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show member list by default',
              style: TextStyle(fontSize: 13)),
          subtitle: Text('Wide screens open channels with the roster visible.',
              style: TextStyle(fontSize: 11, color: c.muted)),
          value: prefs.startWithMembers,
          onChanged: prefs.setStartWithMembers,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reduce motion', style: TextStyle(fontSize: 13)),
          subtitle: Text('Disable animated transitions and scroll easing.',
              style: TextStyle(fontSize: 11, color: c.muted)),
          value: prefs.reduceMotion,
          onChanged: prefs.setReduceMotion,
        ),
        const SectionLabel('Time'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '12h', label: Text('12-hour')),
            ButtonSegment(value: '24h', label: Text('24-hour')),
          ],
          selected: {prefs.use24h ? '24h' : '12h'},
          onSelectionChanged: (value) => prefs.setTimeFormat(value.first),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Chat behaviour
// -----------------------------------------------------------------------------

class _ChatTab extends StatelessWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context) {
    final prefs = FlackleScope.of(context).prefs;
    final c = context.c;
    Widget toggle(String title, String subtitle, bool value,
            ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontSize: 13)),
          subtitle:
              Text(subtitle, style: TextStyle(fontSize: 11, color: c.muted)),
          value: value,
          onChanged: onChanged,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Composer', style: context.display(18, weight: FontWeight.w600)),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'enter', label: Text('Enter sends')),
            ButtonSegment(value: 'mod-enter', label: Text('Mod+Enter sends')),
          ],
          selected: {prefs.sendOnEnter ? 'enter' : 'mod-enter'},
          onSelectionChanged: (value) => prefs.setSendKey(value.first),
        ),
        const SectionLabel('Typing'),
        toggle(
            'Show typing indicators',
            'Display who is typing above the composer.',
            prefs.showTyping,
            prefs.setShowTyping),
        toggle('Share my typing state', 'Send typing events when you write.',
            prefs.shareTyping, prefs.setShareTyping),
        const SectionLabel('Messages'),
        toggle('Link previews', 'Render rich previews for links in messages.',
            prefs.linkPreviews, prefs.setLinkPreviews),
        toggle('Character counter', 'Show the character count while writing.',
            prefs.characterCounter, prefs.setCharacterCounter),
        toggle('Mention avatars', 'Show avatars next to resolved mentions.',
            prefs.mentionAvatars, prefs.setMentionAvatars),
        toggle('Quick reactions', 'Show emoji shortcuts on message hover.',
            prefs.quickReactions, prefs.setQuickReactions),
        toggle(
            'Show my display name',
            'Use display names instead of usernames in chat.',
            prefs.showMeYourName,
            prefs.setShowMeYourName),
        toggle(
            'Keep current channel',
            'Reopen the same channel when you return.',
            prefs.keepCurrentChannel,
            prefs.setKeepCurrentChannel),
        toggle('Channel icons', 'Render server-defined channel icons.',
            prefs.viewIcons, prefs.setViewIcons),
        toggle('Attachment expiry', 'Show when uploaded attachments expire.',
            prefs.showMediaExpiry, prefs.setShowMediaExpiry),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Notifications
// -----------------------------------------------------------------------------

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final prefs = state.prefs;
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notifications',
            style: context.display(18, weight: FontWeight.w600)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('In-app notifications',
              style: TextStyle(fontSize: 13)),
          subtitle: Text('Show mentions and replies while the app is open.',
              style: TextStyle(fontSize: 11, color: c.muted)),
          value: prefs.notifications,
          onChanged: prefs.setNotifications,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mentions only', style: TextStyle(fontSize: 13)),
          subtitle: Text('Silence unread activity that does not mention you.',
              style: TextStyle(fontSize: 11, color: c.muted)),
          value: prefs.mentionsOnly,
          onChanged: prefs.setMentionsOnly,
        ),
        const SectionLabel('Per-server levels'),
        Text(
          'Server owners and admins choose the default notification level. Your per-server choice overrides it here.',
          style: context.label(11.5, color: c.muted, height: 1.5),
        ),
        const SizedBox(height: 10),
        for (final server in state.servers)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                AppAvatar(
                    url: server.iconUrl,
                    name: server.name,
                    size: 26,
                    square: true),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(12.5)),
                ),
                DropdownButton<String>(
                  value: state.serverSettings[server.id]?.notificationLevel ??
                      'all',
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All messages')),
                    DropdownMenuItem(
                        value: 'mentions', child: Text('Mentions only')),
                    DropdownMenuItem(value: 'nothing', child: Text('Nothing')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    try {
                      await state.client.updateServerUserSettings(server.id, {
                        'notification_level': value,
                      });
                      final current = state.serverSettings[server.id];
                      state.serverSettings[server.id] = ServerUserSettings(
                        serverId: server.id,
                        notificationLevel: value,
                        lastViewedChannelId: current?.lastViewedChannelId,
                        collapsedCategories:
                            current?.collapsedCategories ?? const [],
                      );
                    } catch (failure) {
                      if (context.mounted)
                        showAppToast(context, failure.toString());
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Security
// -----------------------------------------------------------------------------

class _SecurityTab extends StatefulWidget {
  const _SecurityTab();

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  TwoFactorStatus? _status;
  List<AuthSession> _sessions = const [];
  List<SecurityEvent> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = FlackleScope.read(context).client;
    try {
      final results = await Future.wait([
        client
            .fetchTwoFactorStatus()
            .catchError((Object _) => const TwoFactorStatus()),
        client.fetchSessions().catchError((Object _) => <AuthSession>[]),
        client
            .fetchSecurityEvents()
            .catchError((Object _) => <SecurityEvent>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as TwoFactorStatus;
        _sessions = results[1] as List<AuthSession>;
        _events = results[2] as List<SecurityEvent>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setup2fa() async {
    final client = FlackleScope.read(context).client;
    final password = TextEditingController();
    final entered = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable two-factor'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Account password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (entered != true || !mounted) {
      password.dispose();
      return;
    }
    try {
      final setup = await client.setupTwoFactor(password.text);
      password.dispose();
      if (!mounted) return;
      await _confirm2fa(setup);
    } catch (failure) {
      password.dispose();
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _confirm2fa(TwoFactorSetup setup) async {
    final client = FlackleScope.read(context).client;
    final code = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm two-factor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (setup.qrCode != null) _qr(setup.qrCode!),
              const SizedBox(height: 10),
              Text('Secret',
                  style: TextStyle(fontSize: 11, color: context.c.muted)),
              SelectableText(setup.secret,
                  style: const TextStyle(fontSize: 13, letterSpacing: 1)),
              if (setup.otpauthUrl != null)
                TextButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: setup.otpauthUrl!)),
                  child: const Text('Copy otpauth URL'),
                ),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await client.confirmTwoFactor(code.text.trim());
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showAppToast(context, 'Two-factor enabled.');
                }
                await _load();
              } catch (failure) {
                if (context.mounted) showAppToast(context, failure.toString());
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    code.dispose();
  }

  Widget _qr(String value) {
    try {
      if (value.startsWith('data:image')) {
        final data = base64Decode(value.split(',').last);
        return Image.memory(Uint8List.fromList(data), height: 180);
      }
      if (value.startsWith('http')) {
        return Image.network(value, height: 180);
      }
      return Image.network(
          'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(value)}',
          height: 180,
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _disable2fa() async {
    final client = FlackleScope.read(context).client;
    final password = TextEditingController();
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable two-factor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: code,
              decoration: const InputDecoration(
                  labelText: 'Authenticator or backup code'),
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
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await client.disableTwoFactor(password.text, code: code.text.trim());
        if (mounted) showAppToast(context, 'Two-factor disabled.');
        await _load();
      } catch (failure) {
        if (mounted) showAppToast(context, failure.toString());
      }
    }
    password.dispose();
    code.dispose();
  }

  Future<void> _backupCodes() async {
    final client = FlackleScope.read(context).client;
    final password = TextEditingController();
    final code = TextEditingController();
    List<String>? codes;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Backup codes'),
          content: SizedBox(
            width: 360,
            child: codes == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: code,
                        decoration: const InputDecoration(
                            labelText: 'Authenticator code'),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in codes!)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: context.c.panel2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.c.line),
                          ),
                          child: SelectableText(value,
                              style: const TextStyle(
                                  fontSize: 12, letterSpacing: 0.5)),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close')),
            if (codes == null)
              FilledButton(
                onPressed: () async {
                  try {
                    final generated = await client.createBackupCodes(
                      password.text,
                      code.text.trim(),
                    );
                    setDialogState(() => codes = generated);
                    await _load();
                  } catch (failure) {
                    if (context.mounted)
                      showAppToast(context, failure.toString());
                  }
                },
                child: const Text('Generate'),
              )
            else
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: codes!.join('\n')));
                  if (context.mounted)
                    showAppToast(context, 'Backup codes copied.');
                },
                child: const Text('Copy all'),
              ),
          ],
        ),
      ),
    );
    password.dispose();
    code.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security', style: context.display(18, weight: FontWeight.w600)),
        if (_loading)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20), child: LoadingPane())
        else ...[
          const SectionLabel('Two-factor authentication'),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: c.panel,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIcon('shield',
                        size: 16,
                        color: _status?.enabled == true ? c.green : c.muted),
                    const SizedBox(width: 8),
                    Text(_status?.enabled == true ? 'Enabled' : 'Not enabled',
                        style: context.label(13, weight: FontWeight.w600)),
                    const Spacer(),
                    if (_status?.enabled == true)
                      Text('${_status?.backupCodesRemaining ?? 0} backup codes',
                          style: context.label(10.5, color: c.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_status?.enabled == true) ...[
                      OutlinedButton(
                          onPressed: _backupCodes,
                          child: const Text('Backup codes')),
                      OutlinedButton(
                        onPressed: _disable2fa,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.danger,
                          side: BorderSide(
                              color: c.danger.withValues(alpha: 0.35)),
                        ),
                        child: const Text('Disable'),
                      ),
                    ] else
                      FilledButton(
                          onPressed: _setup2fa,
                          child: const Text('Enable two-factor')),
                  ],
                ),
              ],
            ),
          ),
          const SectionLabel('Sessions'),
          for (final session in _sessions)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: session.current
                        ? c.accent.withValues(alpha: 0.4)
                        : c.line),
              ),
              child: Row(
                children: [
                  Icon(
                    session.current
                        ? Icons.laptop_rounded
                        : Icons.devices_other_rounded,
                    size: 18,
                    color: session.current ? c.accent : c.muted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.userAgent?.split(' ').first ??
                              'Unknown device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(12, weight: FontWeight.w600),
                        ),
                        Text(
                          [
                            if (session.current) 'This device',
                            if (session.location != null) session.location!,
                            if (session.ipAddress != null) session.ipAddress!,
                            if (session.lastUsedAt != null)
                              relativeTime(session.lastUsedAt),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(10, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  if (!session.current)
                    IconButton(
                      onPressed: () async {
                        final confirmed = await confirmAction(context,
                            title: 'Revoke this session?',
                            body: 'That device will need to sign in again.',
                            confirmLabel: 'Revoke',
                            danger: true);
                        if (!confirmed) return;
                        try {
                          await FlackleScope.read(context)
                              .client
                              .revokeSession(session.id);
                          await _load();
                        } catch (failure) {
                          if (context.mounted)
                            showAppToast(context, failure.toString());
                        }
                      },
                      tooltip: 'Revoke',
                      icon: const Icon(Icons.logout_rounded, size: 16),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final confirmed = await confirmAction(context,
                    title: 'Sign out everywhere?',
                    body: 'Every other device will be signed out.',
                    confirmLabel: 'Sign out all',
                    danger: true);
                if (!confirmed) return;
                try {
                  await FlackleScope.read(context).client.revokeAllSessions();
                  await _load();
                } catch (failure) {
                  if (context.mounted)
                    showAppToast(context, failure.toString());
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 15),
              label: const Text('Sign out all other sessions'),
            ),
          ),
          const SectionLabel('Security activity'),
          if (_events.isEmpty)
            Text('No recent security events.',
                style: context.label(11.5, color: c.muted))
          else
            for (final event in _events.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      event.unusual
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 15,
                      color: event.unusual ? c.yellow : c.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.eventType.replaceAll('_', ' '),
                            style: context.label(11.5, weight: FontWeight.w600),
                          ),
                          Text(
                            [
                              if (event.originLocation != null)
                                event.originLocation!,
                              if (event.createdAt != null)
                                relativeTime(event.createdAt),
                            ].join(' · '),
                            style: context.label(10, color: c.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          TextButton(
            onPressed: () async {
              try {
                await FlackleScope.read(context).client.clearSecurityEvents();
                await _load();
              } catch (failure) {
                if (context.mounted) showAppToast(context, failure.toString());
              }
            },
            child: const Text('Clear security activity'),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// About
// -----------------------------------------------------------------------------

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const FlackleMark(size: 44),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flackle Mobile',
                    style: context.display(20, weight: FontWeight.w600)),
                Text('Version 1.0.0 · Flutter',
                    style: context.label(11.5, color: c.muted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'A native Android, iOS and web client for Flackle, built with the same graphite-and-ember design language as Flackle Desktop.',
          style: context.label(12.5, color: c.textDim, height: 1.6),
        ),
        const SectionLabel('Links'),
        _link(context, 'Flackle', 'https://flackle.com'),
        _link(context, 'Flackle Desktop repository',
            'https://github.com/gaxolotl/flackle-tauri'),
        const SectionLabel('Disclaimer'),
        Text(
          'This is an unofficial client. It is not affiliated with Flackle or Folkward LLC. Never enter your password anywhere except flackle.com.',
          style: context.label(11.5, color: c.muted, height: 1.55),
        ),
        const SectionLabel('Preferences'),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await confirmAction(context,
                title: 'Reset preferences?',
                body:
                    'Theme, density, accent and chat options return to their defaults.',
                confirmLabel: 'Reset');
            if (!confirmed) return;
            await FlackleScope.read(context).prefs.reset();
            if (context.mounted) showAppToast(context, 'Preferences reset.');
          },
          icon: const Icon(Icons.restore_rounded, size: 15),
          label: const Text('Reset all preferences'),
        ),
        const SizedBox(height: 10),
        Text(
          'Rendered with the bundled Twemoji set and the Satoshi and Manrope typefaces.',
          style: context.label(10.5, color: c.muted),
        ),
      ],
    );
  }

  Widget _link(BuildContext context, String label, String url) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                AppIcon('link', size: 14, color: context.c.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: context.label(12.5, color: context.c.accent)),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 13, color: context.c.muted),
              ],
            ),
          ),
        ),
      );
}
