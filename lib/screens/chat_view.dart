import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/media.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../core/prefs.dart';
import '../core/state.dart';
import '../core/theme.dart';
import '../ui/common.dart';
import '../ui/emoji.dart';
import '../ui/icons.dart';
import 'channel_dialog.dart';
import 'group_dm_sheet.dart';
import 'member_panel.dart';
import 'server_settings_screen.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.target, super.key});

  final Target target;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum _SuggestionKind { user, role, channel }

class _ComposerSuggestion {
  const _ComposerSuggestion({
    required this.kind,
    required this.id,
    required this.label,
    required this.detail,
    this.user,
    this.role,
    this.channel,
  });

  final _SuggestionKind kind;
  final String id;
  final String label;
  final String detail;
  final User? user;
  final Role? role;
  final Channel? channel;
}

class _ChatPageState extends State<ChatPage> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final serverId = widget.target.serverId;
    return Scaffold(
      key: _scaffold,
      endDrawer: serverId == null
          ? null
          : Drawer(
              width: MediaQuery.sizeOf(context).width * 0.84,
              backgroundColor: context.c.sidebar,
              child: SafeArea(
                child: MemberPanel(
                  serverId: serverId,
                  embedded: true,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: ChatView(
          target: widget.target,
          embedded: false,
          onBack: () => Navigator.of(context).maybePop(),
          onToggleMembers: serverId == null
              ? null
              : () => _scaffold.currentState?.openEndDrawer(),
        ),
      ),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({
    required this.target,
    this.embedded = true,
    this.onBack,
    this.onToggleMembers,
    super.key,
  });

  final Target target;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onToggleMembers;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  final _focus = FocusNode();
  Message? _reply;
  Message? _editing;
  final List<Attachment> _attachments = [];
  bool _sending = false;
  bool _uploading = false;
  String? _hoveredId;
  String? _lastMessageId;
  Timer? _typingTimer;
  Timer? _draftTimer;
  late final AppPrefs _prefs;
  final Set<String> _menuOpen = {};
  final List<_ComposerSuggestion> _suggestions = [];
  int _suggestionStart = -1;

  AppState get _state => FlackleScope.read(context);

  @override
  void initState() {
    super.initState();
    _prefs = FlackleScope.read(context).prefs;
    final draft = _prefs.draft(widget.target.key);
    if (draft.isNotEmpty) {
      _composer.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _jumpToBottom(animate: false));
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.key != widget.target.key) {
      _draftTimer?.cancel();
      unawaited(_prefs.setDraft(oldWidget.target.key, _composer.text));
      _reply = null;
      _editing = null;
      _attachments.clear();
      _composer.clear();
      final draft = _prefs.draft(widget.target.key);
      if (draft.isNotEmpty) {
        _composer.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length),
        );
      }
      _lastMessageId = null;
      _suggestions.clear();
      _suggestionStart = -1;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _jumpToBottom(animate: false));
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _draftTimer?.cancel();
    unawaited(_prefs.setDraft(widget.target.key, _composer.text));
    _scroll.dispose();
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _saveDraftSoon(String value) {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_prefs.setDraft(widget.target.key, value));
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // The list is reversed, so older messages live past the leading edge.
    if (position.extentAfter <= 260 && _state.hasMoreBefore) {
      unawaited(_state.loadOlder());
    }
  }

  bool get _nearBottom {
    if (!_scroll.hasClients) return false;
    return _scroll.position.pixels <= 24;
  }

  void _jumpToBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.minScrollExtent;
    if (animate && !_state.prefs.reduceMotion) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 190), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _onComposerChanged(String value) {
    if (_state.prefs.shareTyping && value.trim().isNotEmpty) {
      _state.notifyTyping();
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 5), _state.stopTyping);
    }
    _saveDraftSoon(value);
    setState(() {});
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    final state = _state;
    final target = widget.target;
    final text = _composer.text;
    final selection = _composer.selection;
    var cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) cursor = text.length;
    var start = cursor;
    while (start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])) {
      start -= 1;
    }
    if (start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])) {
      _clearSuggestions();
      return;
    }
    final token = text.substring(start, cursor);
    if (token.isEmpty || (token[0] != '@' && token[0] != '#')) {
      _clearSuggestions();
      return;
    }
    final query = token.substring(1).toLowerCase();
    if (query.contains('@') || query.contains('#')) {
      _clearSuggestions();
      return;
    }
    final serverId = target.serverId;
    final suggestions = <_ComposerSuggestion>[];
    if (token[0] == '@') {
      if (serverId != null) {
        final canMentionAll =
            state.can(Permission.mentionEveryone, serverId: serverId);
        for (final member in state.membersFor(serverId)) {
          if (!_matchesMember(member, query)) continue;
          suggestions.add(_ComposerSuggestion(
            kind: _SuggestionKind.user,
            id: member.user.id,
            label: member.displayName,
            detail: member.user.handle,
            user: member.user,
          ));
        }
        for (final role in state.roles[serverId] ?? const <Role>[]) {
          if (!canMentionAll && !role.mentionable) continue;
          if (!role.name.toLowerCase().contains(query)) continue;
          suggestions.add(_ComposerSuggestion(
            kind: _SuggestionKind.role,
            id: role.id,
            label: role.name,
            detail: 'Role',
            role: role,
          ));
        }
        if (state.roles[serverId] == null) {
          unawaited(state.loadRoles(serverId).then((_) {
            if (mounted && _suggestionStart >= 0) _refreshSuggestions();
          }));
        }
        if (state.members[serverId] == null) {
          unawaited(state.loadMembers(serverId).then((_) {
            if (mounted && _suggestionStart >= 0) _refreshSuggestions();
          }));
        }
      } else {
        final conversation = state.conversations
            .where((entry) => entry.id == target.conversationId)
            .firstOrNull;
        for (final member in conversation?.members ?? const []) {
          final user = member.user;
          if (query.isNotEmpty &&
              !user.name.toLowerCase().contains(query) &&
              !user.username.toLowerCase().contains(query)) {
            continue;
          }
          suggestions.add(_ComposerSuggestion(
            kind: _SuggestionKind.user,
            id: user.id,
            label: user.name,
            detail: user.handle,
            user: user,
          ));
        }
      }
    } else if (serverId != null) {
      for (final channel in state.visibleChannels(serverId)) {
        if (!channel.name.toLowerCase().contains(query)) continue;
        suggestions.add(_ComposerSuggestion(
          kind: _SuggestionKind.channel,
          id: channel.id,
          label: channel.name,
          detail: channel.type,
          channel: channel,
        ));
      }
    }
    setState(() {
      _suggestionStart = start;
      _suggestions
        ..clear()
        ..addAll(suggestions.take(10));
    });
  }

  bool _matchesMember(Member member, String query) {
    if (query.isEmpty) return true;
    return member.displayName.toLowerCase().contains(query) ||
        member.user.username.toLowerCase().contains(query);
  }

  void _clearSuggestions() {
    if (_suggestions.isEmpty && _suggestionStart < 0) return;
    setState(() {
      _suggestions.clear();
      _suggestionStart = -1;
    });
  }

  void _applySuggestion(_ComposerSuggestion suggestion) {
    if (_suggestionStart < 0) return;
    final text = _composer.text;
    final selection = _composer.selection;
    var cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) cursor = text.length;
    final markup = switch (suggestion.kind) {
      _SuggestionKind.user => '<@${suggestion.id}>',
      _SuggestionKind.role => '<@&${suggestion.id}>',
      _SuggestionKind.channel => '<#${suggestion.id}>',
    };
    final insertion = '$markup ';
    final next = text.replaceRange(_suggestionStart, cursor, insertion);
    final offset = _suggestionStart + insertion.length;
    _composer.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset),
    );
    _saveDraftSoon(next);
    _clearSuggestions();
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (_sending) return;
    if (text.isEmpty && _attachments.isEmpty) return;
    final state = _state;
    setState(() => _sending = true);
    try {
      if (_editing != null) {
        await state.editMessage(_editing!, text);
        setState(() {
          _editing = null;
          _composer.clear();
        });
        _draftTimer?.cancel();
        unawaited(_prefs.clearDraft(widget.target.key));
      } else {
        await state.sendMessage(
          text,
          attachments: List.of(_attachments),
          replyTo: _reply?.id,
        );
        setState(() {
          _composer.clear();
          _attachments.clear();
          _reply = null;
        });
        _draftTimer?.cancel();
        unawaited(_prefs.clearDraft(widget.target.key));
        if (_state.prefs.characterCounter) setState(() {});
      }
      _typingTimer?.cancel();
      state.stopTyping();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _jumpToBottom();
      _focus.requestFocus();
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachments() async {
    final target = _state.active;
    if (target == null) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform
          .pickFiles(allowMultiple: true, withData: true);
    } catch (failure) {
      if (mounted)
        showAppToast(context, 'Could not open the file picker: $failure');
      return;
    }
    if (result == null) return;
    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          if (mounted) showAppToast(context, '${file.name} could not be read.');
          continue;
        }
        final attachment =
            await _state.client.uploadAttachment(target, file.name, bytes);
        if (mounted) setState(() => _attachments.add(attachment));
      }
    } catch (failure) {
      if (mounted) showAppToast(context, 'Upload failed: $failure');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _insertEmoji() async {
    final emoji = await showEmojiPicker(
      context,
      allowGifs: true,
      loadGifs: (query, page) =>
          _state.client.fetchGifs(query: query, page: page),
    );
    if (emoji == null) return;
    final selection = _composer.selection;
    final text = _composer.text;
    final start = selection.start == -1 ? text.length : selection.start;
    final end = selection.end == -1 ? text.length : selection.end;
    final next = text.replaceRange(start, end, emoji);
    _composer.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focus.requestFocus();
    _onComposerChanged(next);
  }

  void _startReply(Message message) {
    setState(() {
      _reply = message;
      _editing = null;
    });
    _focus.requestFocus();
  }

  void _startEdit(Message message) {
    setState(() {
      _editing = message;
      _reply = null;
      _composer.text = message.content;
      _composer.selection =
          TextSelection.collapsed(offset: _composer.text.length);
    });
    _focus.requestFocus();
  }

  Future<void> _confirmDelete(Message message) async {
    final confirmed = await confirmAction(context,
        title: 'Delete message?',
        body: 'This removes it for everyone in the channel.',
        confirmLabel: 'Delete',
        danger: true);
    if (!confirmed) return;
    try {
      await _state.deleteMessage(message);
      if (mounted) showAppToast(context, 'Message deleted.');
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  bool _canDelete(Message message) {
    final mine = message.author?.id == _state.me?.id;
    return mine || _state.can(Permission.manageMessages);
  }

  Future<void> _showMessageMenu(Message message) async {
    if (_menuOpen.contains(message.id)) return;
    _menuOpen.add(message.id);
    final state = _state;
    final mine = message.author?.id == state.me?.id;
    await showAppMenu(context, title: 'Message actions', entries: [
      MenuEntry(
        label: 'Add reaction',
        icon: 'smile',
        run: () async {
          final emoji = await showEmojiPicker(context, title: 'React');
          if (emoji == null) return;
          try {
            await state.toggleReaction(message, emoji);
          } catch (failure) {
            if (context.mounted) showAppToast(context, failure.toString());
          }
        },
      ),
      MenuEntry(label: 'Reply', icon: 'reply', run: () => _startReply(message)),
      if (mine)
        MenuEntry(
            label: 'Edit', icon: 'pencil', run: () => _startEdit(message)),
      if (_canDelete(message))
        MenuEntry(
          label: 'Delete',
          icon: 'trash',
          danger: true,
          run: () => _confirmDelete(message),
        ),
      const MenuEntry(label: '', separator: true),
      MenuEntry(
        label: 'Copy text',
        icon: 'copy',
        run: () async {
          await Clipboard.setData(ClipboardData(text: message.content));
          if (context.mounted) showAppToast(context, 'Message copied.');
        },
      ),
      MenuEntry(
        label: 'Copy message link',
        icon: 'link',
        run: () async {
          final target = state.active;
          if (target == null) return;
          final link = target.isChannel
              ? 'https://flackle.com/app/channels/${target.serverId}/${target.channelId}#message-${message.id}'
              : 'https://flackle.com/app/dms/${target.conversationId}#message-${message.id}';
          await Clipboard.setData(ClipboardData(text: link));
          if (context.mounted) showAppToast(context, 'Message link copied.');
        },
      ),
      if (message.attachments.isNotEmpty && state.can(Permission.saveMedia))
        MenuEntry(
          label: 'Save attachments',
          icon: 'download',
          run: () => showAppToast(
              context, 'Attachments are already hosted on Flackle.'),
        ),
      const MenuEntry(label: '', separator: true),
      MenuEntry(
        label: 'View profile',
        icon: 'user',
        run: () {
          final author = message.author;
          if (author == null) return;
          showProfile(
            context,
            user: author,
            member: message.author == null || state.active?.serverId == null
                ? null
                : state.memberById(state.active!.serverId!, author.id),
            serverId: state.active?.serverId,
          );
        },
      ),
    ]);
    _menuOpen.remove(message.id);
  }

  Future<void> _quickReact(Message message, String emoji) async {
    try {
      await _state.toggleReaction(message, emoji);
    } catch (failure) {
      if (mounted) showAppToast(context, failure.toString());
    }
  }

  Future<void> _channelMenu() async {
    final state = _state;
    final target = widget.target;
    if (!target.isChannel) return;
    final channel = state.channelById(target.serverId!, target.channelId!);
    final canManage = state.can(Permission.manageChannels);
    await showAppMenu(context, title: target.title, entries: [
      if (canManage)
        MenuEntry(
          label: 'Edit channel',
          icon: 'pencil',
          run: () => openChannelDialog(
            context,
            serverId: target.serverId!,
            channel: channel,
          ),
        ),
      if (canManage) ...[
        MenuEntry(
          label: 'Server settings',
          icon: 'sliders',
          run: () => openServerSettings(context, serverId: target.serverId!),
        ),
        const MenuEntry(label: '', separator: true),
      ],
      MenuEntry(
        label: 'Copy channel link',
        icon: 'link',
        run: () async {
          await Clipboard.setData(ClipboardData(
              text:
                  'https://flackle.com/app/channels/${target.serverId}/${target.channelId}'));
          if (context.mounted) showAppToast(context, 'Channel link copied.');
        },
      ),
      MenuEntry(
        label: 'Mark as read',
        icon: 'check',
        run: () async {
          if (state.messages.isNotEmpty) {
            await state.client.markRead(target, state.messages.last.id);
            state.unread.remove(target.channelId);
          }
        },
      ),
      MenuEntry(
        label: state.serverSettings[target.serverId!]?.notificationLevel ==
                'nothing'
            ? 'Unmute server'
            : 'Mute server',
        icon: 'bell',
        run: () async {
          final current =
              state.serverSettings[target.serverId!]?.notificationLevel;
          final next = current == 'nothing' ? 'all' : 'nothing';
          try {
            await state.client.updateServerUserSettings(target.serverId!, {
              'notification_level': next,
            });
            final currentSettings = state.serverSettings[target.serverId!];
            state.serverSettings[target.serverId!] = currentSettings == null
                ? ServerUserSettings(
                    serverId: target.serverId!,
                    notificationLevel: next,
                    lastViewedChannelId: target.channelId,
                  )
                : currentSettings.copyWith(
                    notificationLevel: next,
                    lastViewedChannelId: target.channelId,
                  );
            if (context.mounted) {
              showAppToast(context,
                  next == 'nothing' ? 'Server muted.' : 'Server unmuted.');
            }
          } catch (failure) {
            if (context.mounted) showAppToast(context, failure.toString());
          }
        },
      ),
    ]);
  }

  Future<void> _search() async {
    final query = TextEditingController();
    final messages = List<Message>.from(_state.messages.reversed);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final term = query.text.trim().toLowerCase();
          final results = term.isEmpty
              ? const <Message>[]
              : messages
                  .where(
                      (message) => message.content.toLowerCase().contains(term))
                  .take(40)
                  .toList();
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: query,
                            autofocus: true,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search this conversation',
                              prefixIcon: Icon(Icons.search_rounded, size: 18),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: term.isEmpty
                        ? Center(
                            child: Text('Type to search loaded messages.',
                                style: TextStyle(
                                    color: context.c.muted, fontSize: 12)),
                          )
                        : results.isEmpty
                            ? Center(
                                child: Text('No matches in this conversation.',
                                    style: TextStyle(
                                        color: context.c.muted, fontSize: 12)),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 4, 10, 14),
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    Divider(color: context.c.line),
                                itemBuilder: (context, index) {
                                  final message = results[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(message.authorName,
                                        style: const TextStyle(fontSize: 12)),
                                    subtitle: Text(message.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12)),
                                    trailing: Text(
                                        formatTime(message.createdAt,
                                            use24h: _state.prefs.use24h),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: context.c.muted)),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _scrollToMessage(message.id);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    query.dispose();
  }

  void _scrollToMessage(String messageId) {
    final chronological =
        _state.messages.indexWhere((message) => message.id == messageId);
    if (chronological == -1 || !_scroll.hasClients) return;
    final index = _state.messages.length - 1 - chronological;
    final approximate =
        (index * 64.0).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
    _scroll.animateTo(approximate,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    final target = widget.target;
    final c = context.c;
    final messages = state.messages;
    final last = messages.isEmpty ? null : messages.last.id;
    if (last != null && last != _lastMessageId) {
      final wasNearBottom = _nearBottom;
      _lastMessageId = last;
      if (wasNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      }
    }

    return Container(
      color: c.chat,
      child: Column(
        children: [
          _header(context, state, target),
          Expanded(
            child: state.loadingMessages && messages.isEmpty
                ? const LoadingPane()
                : state.messagesError != null && messages.isEmpty
                    ? ErrorPane(
                        message: state.messagesError!,
                        onRetry: () => state.loadMessages(),
                      )
                    : messages.isEmpty
                        ? EmptyPane(
                            icon: target.isChannel
                                ? Icons.forum_outlined
                                : Icons.waving_hand_outlined,
                            title: target.isChannel
                                ? 'This is the start of #${target.title}'
                                : 'Say hello to ${target.title}',
                            detail:
                                'Send the first message to get things going.',
                          )
                        : _messageList(context, state, messages),
          ),
          if (state.prefs.showTyping) _typingLine(context, state, target),
          _composerBar(context, state, target),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppState state, Target target) {
    final c = context.c;
    final channel = target.isChannel && target.serverId != null
        ? state.channelById(target.serverId!, target.channelId!)
        : null;
    final conversation = target.isChannel
        ? null
        : state.conversations
            .where((entry) => entry.id == target.conversationId)
            .firstOrNull;
    final presenceNames = state.typingNames(target);
    return Container(
      height: 54,
      padding: EdgeInsets.only(left: widget.embedded ? 16 : 4, right: 6),
      decoration: BoxDecoration(
        color: c.chat,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          if (!widget.embedded && widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              tooltip: 'Back',
            ),
          if (target.isChannel)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: ChannelGlyph(
                name: channel?.icon ?? target.icon,
                color: channel?.iconColor ?? target.iconColor,
                type: channel?.type ?? target.channelType,
                size: 18,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: AppAvatar(
                url: conversation?.isGroup == true
                    ? conversation?.iconUrl
                    : conversation?.otherUser(state.me?.id ?? '')?.avatarUrl,
                name: target.title ?? 'Direct message',
                size: 28,
              ),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: EmojiText(
                        target.title ?? 'Flackle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.display(15, weight: FontWeight.w600),
                      ),
                    ),
                    if (target.isChannel &&
                        channel?.slowmodeSeconds != null &&
                        channel!.slowmodeSeconds! > 0) ...[
                      const SizedBox(width: 7),
                      Tag('SLOW ${formatSlowmode(channel.slowmodeSeconds!)}',
                          small: true),
                    ],
                    if (!state.isConnected) ...[
                      const SizedBox(width: 7),
                      Tooltip(
                        message:
                            'Live connection lost  -  messages refresh on send.',
                        child: Icon(Icons.cloud_off_rounded,
                            size: 13, color: c.yellow),
                      ),
                    ],
                  ],
                ),
                if (channel?.topic?.isNotEmpty == true)
                  Text(
                    channel!.topic!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.label(10.5, color: c.muted),
                  )
                else if (presenceNames.isNotEmpty)
                  Text(
                    '${presenceNames.take(2).join(', ')} typing...',
                    style: context.label(10.5, color: c.muted),
                  )
                else if (conversation?.isGroup == true)
                  Text(
                    '${conversation!.members.length} members',
                    style: context.label(10.5, color: c.muted),
                  ),
              ],
            ),
          ),
          if (conversation?.isGroup == true)
            IconButton(
              onPressed: () => showGroupDmSheet(context, conversation!),
              tooltip: 'Group details',
              icon: const Icon(Icons.group_outlined, size: 19),
            ),
          IconButton(
            onPressed: _search,
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded, size: 19),
          ),
          if (target.isChannel && widget.onToggleMembers != null)
            IconButton(
              onPressed: widget.onToggleMembers,
              tooltip: 'Members',
              icon: const Icon(Icons.people_alt_outlined, size: 19),
            ),
          if (target.isChannel)
            IconButton(
              onPressed: _channelMenu,
              tooltip: 'Channel options',
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
            )
          else
            IconButton(
              onPressed: () {
                final conversation = state.conversations
                    .where((entry) => entry.id == target.conversationId)
                    .firstOrNull;
                final other = conversation?.otherUser(state.me?.id ?? '');
                if (other != null) showProfile(context, user: other);
              },
              tooltip: 'Profile',
              icon: const Icon(Icons.person_outline_rounded, size: 19),
            ),
        ],
      ),
    );
  }

  Widget _messageList(
      BuildContext context, AppState state, List<Message> messages) {
    final c = context.c;
    // Reversed chat lists keep the viewport anchored when older pages are
    // prepended: new rows are appended past the leading edge instead of
    // shifting everything currently on screen.
    final ordered = messages.reversed.toList(growable: false);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      itemCount: ordered.length + (state.hasMoreBefore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.hasMoreBefore && index == ordered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: state.loadingOlder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: state.loadOlder,
                      child: const Text('Load earlier messages'),
                    ),
            ),
          );
        }
        final message = ordered[index];
        final previous = index + 1 < ordered.length ? ordered[index + 1] : null;
        final grouped = previous != null &&
            previous.type != 'system' &&
            message.type != 'system' &&
            previous.author?.id == message.author?.id &&
            previous.replyTo == null &&
            message.replyTo == null &&
            previous.createdAt != null &&
            message.createdAt != null &&
            message.createdAt!.difference(previous.createdAt!).inMinutes < 5 &&
            !_needsDateDivider(previous, message);
        final showDate =
            previous == null || _needsDateDivider(previous, message);
        final inlineImage = _inlineImageLink(message.content);
        final contentIsOnlyLink =
            inlineImage != null && message.content.trim() == inlineImage;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _dateDivider(context, message.createdAt),
            MouseRegion(
              onEnter: (_) => setState(() => _hoveredId = message.id),
              onExit: (_) => setState(() {
                if (_hoveredId == message.id) _hoveredId = null;
              }),
              child: GestureDetector(
                onLongPress: () => _showMessageMenu(message),
                onSecondaryTap: () => _showMessageMenu(message),
                child: Stack(
                  children: [
                    Container(
                      color: _hoveredId == message.id
                          ? c.hover
                          : Colors.transparent,
                      padding: EdgeInsets.fromLTRB(
                        14,
                        state.prefs.compact ? 2 : 3,
                        12,
                        message.reactions.isEmpty
                            ? (state.prefs.compact ? 2 : 4)
                            : 3,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 38,
                            child: grouped
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: GestureDetector(
                                      onTap: message.author == null
                                          ? null
                                          : () => showProfile(
                                                context,
                                                user: message.author!,
                                                member: state
                                                            .active?.serverId ==
                                                        null
                                                    ? null
                                                    : state.memberById(
                                                        state.active!.serverId!,
                                                        message.author!.id),
                                                serverId:
                                                    state.active?.serverId,
                                              ),
                                      child: AppAvatar(
                                        url: message.author?.avatarUrl,
                                        name: message.authorName,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!grouped)
                                  _messageHeader(context, state, message),
                                if (message.replyTo != null)
                                  _replyPreview(
                                      context, state, message.replyTo!),
                                if (message.content.isNotEmpty &&
                                    !contentIsOnlyLink)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: MessageText(
                                      content: message.content,
                                      style: context.label(
                                        _emojiOnly(message.content)
                                            ? 30
                                            : state.prefs.messageFontSize,
                                        color: c.textDim,
                                        height: 1.42,
                                      ),
                                      resolver: MentionResolver(
                                        user: (id) => state.userById(id),
                                        role: (id) => state.active?.serverId ==
                                                null
                                            ? null
                                            : state.roleById(
                                                state.active!.serverId!, id),
                                        channel: (id) =>
                                            state.active?.serverId == null
                                                ? null
                                                : state.channelById(
                                                    state.active!.serverId!,
                                                    id),
                                        onUser: (user) => showProfile(
                                          context,
                                          user: user,
                                          serverId: state.active?.serverId,
                                          member: state.active?.serverId == null
                                              ? null
                                              : state.memberById(
                                                  state.active!.serverId!,
                                                  user.id),
                                        ),
                                        onChannel: (id) {
                                          final serverId =
                                              state.active?.serverId;
                                          if (serverId == null) return;
                                          final channel =
                                              state.channelById(serverId, id);
                                          if (channel != null) {
                                            state.selectChannel(
                                                serverId, channel);
                                          }
                                        },
                                      ),
                                      onOpenUrl: (url) => launchUrl(
                                          Uri.parse(url),
                                          mode: LaunchMode.externalApplication),
                                      onOpenChannel: (id) {
                                        final serverId = state.active?.serverId;
                                        if (serverId == null) return;
                                        final channel =
                                            state.channelById(serverId, id);
                                        if (channel != null) {
                                          state.selectChannel(
                                              serverId, channel);
                                        }
                                      },
                                    ),
                                  ),
                                if (inlineImage != null &&
                                    message.attachments.every(
                                      (attachment) =>
                                          attachment.url != inlineImage,
                                    ))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: _inlineImage(context, inlineImage),
                                  ),
                                for (final attachment in message.attachments)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: _attachment(context, attachment),
                                  ),
                                for (final embed in message.embeds)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: _embed(context, embed),
                                  ),
                                if (message.editedAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text('(edited)',
                                        style: TextStyle(
                                            fontSize: 9.5, color: c.muted)),
                                  ),
                                if (message.reactions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Wrap(
                                      spacing: 5,
                                      runSpacing: 5,
                                      children: [
                                        for (final reaction
                                            in message.reactions)
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            onTap: () => _quickReact(
                                                message, reaction.emoji),
                                            child: ReactionSummary(
                                                reaction: reaction),
                                          ),
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          onTap: () async {
                                            final emoji = await showEmojiPicker(
                                              context,
                                              title: 'React',
                                            );
                                            if (emoji != null)
                                              _quickReact(message, emoji);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: c.panel2,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(color: c.line),
                                            ),
                                            child: Icon(
                                                Icons.add_reaction_outlined,
                                                size: 13,
                                                color: c.muted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (message.pending)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text('Sending...',
                                        style: TextStyle(
                                            fontSize: 9.5, color: c.muted)),
                                  ),
                                if (message.failed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text('Not sent  -  tap to retry',
                                        style: TextStyle(
                                            fontSize: 9.5, color: c.danger)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_hoveredId == message.id)
                      Positioned(
                        top: 0,
                        right: 8,
                        child: _hoverActions(context, state, message),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _emojiOnly(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    final chars = trimmed.characters;
    return chars.length <= 6 &&
        chars.every((g) => EmojiIndex.isEmoji(g) || g.trim().isEmpty);
  }

  Widget _messageHeader(BuildContext context, AppState state, Message message) {
    final c = context.c;
    final member = state.active?.serverId == null || message.author == null
        ? null
        : state.memberById(state.active!.serverId!, message.author!.id);
    final topRole = _topRole(state, member);
    final roleColor = parseHex(topRole?.color);
    final hasRoleIcon = topRole != null &&
        (topRole.iconUrl?.isNotEmpty == true ||
            topRole.iconEmoji?.isNotEmpty == true);
    final name = state.prefs.showMeYourName
        ? message.authorName
        : message.author?.username ?? message.authorName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasRoleIcon) ...[
            RoleIcon(role: topRole, size: 13),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.label(
                13.5,
                weight: FontWeight.w700,
                color: roleColor ??
                    (message.author?.id == state.me?.id ? c.accent : c.text),
              ),
            ),
          ),
          if (member?.isOwner == true) ...[
            const SizedBox(width: 4),
            const AppIcon('crown', size: 11, color: Color(0xFFE0A13D)),
          ],
          if (message.type == 'system') ...[
            const SizedBox(width: 6),
            Tag('SYSTEM', small: true),
          ],
          const SizedBox(width: 6),
          Text(
            formatTime(message.createdAt, use24h: state.prefs.use24h),
            style: context.label(9.5, color: c.muted),
          ),
        ],
      ),
    );
  }

  Role? _topRole(AppState state, Member? member) {
    if (member == null || state.active?.serverId == null) return null;
    final roles = state.roles[state.active!.serverId!] ?? const <Role>[];
    Role? top;
    for (final role in roles) {
      if (role.isEveryone || !member.roleIds.contains(role.id)) continue;
      if (top == null || role.position > top.position) top = role;
    }
    return top;
  }

  Widget _hoverActions(BuildContext context, AppState state, Message message) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.panel2,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.lineStrong),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.prefs.quickReactions)
            for (final emoji in const [
              '\u{1F44D}',
              '\u{2764}\u{FE0F}',
              '\u{1F602}'
            ])
              _hoverButton(
                context,
                onTap: () => _quickReact(message, emoji),
                child: EmojiGlyph(emoji, size: 14),
              ),
          _hoverButton(
            context,
            onTap: () => _startReply(message),
            child: AppIcon('reply', size: 14, color: c.muted),
          ),
          _hoverButton(
            context,
            onTap: () => _showMessageMenu(message),
            child: AppIcon('more', size: 14, color: c.muted),
          ),
        ],
      ),
    );
  }

  Widget _hoverButton(BuildContext context,
      {required VoidCallback onTap, required Widget child}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: child,
      ),
    );
  }

  Widget _replyPreview(
      BuildContext context, AppState state, MessageReply reply) {
    final c = context.c;
    final rawName = reply.authorName.trim();
    final authorLabel =
        rawName.isEmpty || rawName == '###' ? 'Unknown member' : rawName;
    return Container(
      margin: const EdgeInsets.only(top: 3, bottom: 2),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: c.accent.withValues(alpha: 0.6), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reply to $authorLabel',
              style: context.label(10.5,
                  weight: FontWeight.w600, color: c.accent)),
          if (!reply.deleted && reply.content.isNotEmpty)
            MessageText(
              content: reply.content,
              style: context.label(11.5, color: c.muted, height: 1.35),
              resolver: MentionResolver(
                user: (id) => state.userById(id),
                role: (id) => state.active?.serverId == null
                    ? null
                    : state.roleById(state.active!.serverId!, id),
                channel: (id) => state.active?.serverId == null
                    ? null
                    : state.channelById(state.active!.serverId!, id),
              ),
            )
          else
            Text('Original message deleted',
                style: context.label(11, color: c.muted, height: 1.35)),
        ],
      ),
    );
  }

  Widget _attachment(BuildContext context, Attachment attachment) {
    if (attachment.isImage) {
      final c = context.c;
      final rawWidth = (attachment.width ?? 380).toDouble();
      final rawHeight = (attachment.height ?? 240).toDouble();
      final width = rawWidth <= 0 ? 380.0 : rawWidth;
      final height = rawHeight <= 0 ? 240.0 : rawHeight;
      final scale =
          math.min(380.0 / width, 320.0 / height).clamp(0.05, 1.0).toDouble();
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => openImageViewer(context, attachment.url,
                  title: attachment.fileName),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: width * scale,
                  height: height * scale,
                  child: ColoredBox(
                    color: c.panel2,
                    child: AppImage(
                      attachment.url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _brokenAttachment(context, attachment),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: _mediaSaveButton(context, attachment.url),
            ),
          ],
        ),
      );
    }
    return _fileCard(context, attachment);
  }

  Widget _mediaSaveButton(BuildContext context, String url) {
    final state = _state;
    final allowed =
        state.active?.isChannel != true || state.can(Permission.saveMedia);
    if (!allowed) return const SizedBox.shrink();
    final saved = state.savedMediaUrls.contains(url);
    return IconButton(
      tooltip: saved ? 'Remove from saved media' : 'Save media',
      onPressed: () async {
        try {
          final nowSaved = await state.toggleSavedMedia(url);
          if (context.mounted) {
            showAppToast(
              context,
              nowSaved ? 'Saved to your media.' : 'Removed from saved media.',
            );
          }
        } catch (failure) {
          if (context.mounted) showAppToast(context, failure.toString());
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        minimumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 15),
    );
  }

  Widget _brokenAttachment(BuildContext context, Attachment attachment) {
    final c = context.c;
    return Container(
      color: c.panel2,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 26, color: c.muted),
          const SizedBox(height: 7),
          Text('Preview unavailable', style: context.label(11, color: c.muted)),
          const SizedBox(height: 2),
          Text(
            attachment.fileName ?? 'Image',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.label(10, color: c.muted),
          ),
        ],
      ),
    );
  }

  Widget _fileCard(BuildContext context, Attachment attachment) {
    final c = context.c;
    final icon = attachment.isVideo
        ? Icons.play_circle_outline_rounded
        : attachment.isAudio
            ? Icons.audiotrack_rounded
            : Icons.insert_drive_file_outlined;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => launchUrl(Uri.parse(attachment.url),
            mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: c.panel2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: c.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attachment.fileName ?? 'Attachment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.label(12, weight: FontWeight.w600)),
                    Text(
                      [
                        if (attachment.fileSize != null)
                          formatSize(attachment.fileSize),
                        if (attachment.contentType != null)
                          attachment.contentType!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(10, color: c.muted),
                    ),
                  ],
                ),
              ),
              _mediaSaveButton(context, attachment.url),
            ],
          ),
        ),
      ),
    );
  }

  Widget _embed(BuildContext context, Embed embed) {
    if (embed.isInvite) return _inviteEmbed(context, embed);
    final card = embed.hasCardContent ? _linkEmbed(context, embed) : null;
    if (embed.nested.isEmpty) {
      return card ?? const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card != null) card,
        for (final nested in embed.nested)
          Padding(
            padding: EdgeInsets.only(top: card == null ? 0 : 6),
            child: _embed(context, nested),
          ),
      ],
    );
  }

  Widget _inviteEmbed(BuildContext context, Embed embed) {
    final state = FlackleScope.read(context);
    final c = context.c;
    final known =
        embed.serverId == null ? null : state.serverById(embed.serverId!);
    final memberText = [
      if (embed.memberCount != null) '${embed.memberCount} members',
      if (embed.presenceCount != null) '${embed.presenceCount} online',
    ].join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(9),
          border: Border(left: BorderSide(color: c.green, width: 3)),
        ),
        child: Row(
          children: [
            AppAvatar(
              url: embed.serverIconUrl,
              name: embed.serverName ?? 'Server',
              size: 38,
              square: true,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(embed.serverName ?? 'Server invite',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(13, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(memberText.isEmpty ? 'Server invite' : memberText,
                      style: context.label(10, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                if (known != null) {
                  await state.selectServer(known.id);
                  return;
                }
                if (embed.code == null) return;
                try {
                  final result = await state.client.acceptInvite(embed.code!);
                  final server = result['server'] is Map
                      ? Server.fromJson(asMap(result['server']))
                      : null;
                  await state.refreshAll();
                  if (server != null) {
                    await state.selectServer(
                      server.id,
                      preferredChannelId:
                          asStringOrNull(result['landing_channel_id']),
                    );
                  }
                  if (context.mounted) {
                    showAppToast(
                        context,
                        server == null
                            ? 'Joined server.'
                            : 'Joined ${server.name}.');
                  }
                } catch (failure) {
                  if (context.mounted)
                    showAppToast(context, failure.toString());
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: c.green,
              ),
              child: Text(known != null ? 'Open' : 'Join'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkEmbed(BuildContext context, Embed embed) {
    final c = context.c;
    final accent = parseHex(embed.color) ?? c.accent;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(9),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (embed.siteName != null)
              Text(embed.siteName!.toUpperCase(),
                  style: context.label(9,
                      weight: FontWeight.w700,
                      color: c.muted,
                      letterSpacing: 0.7)),
            if (embed.title != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: InkWell(
                  onTap: embed.url == null
                      ? null
                      : () => launchUrl(Uri.parse(embed.url!),
                          mode: LaunchMode.externalApplication),
                  child: Text(embed.title!,
                      style: context.label(13,
                          weight: FontWeight.w600, color: c.accent)),
                ),
              ),
            if (embed.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(embed.description!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: context.label(11.5, color: c.textDim, height: 1.45)),
              ),
            if (embed.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () => openImageViewer(context, embed.imageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: AppImage(embed.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    ),
                  ),
                ),
              ),
            for (final field in embed.fields)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (field.name != null)
                      Text(field.name!,
                          style: context.label(11, weight: FontWeight.w700)),
                    if (field.value != null)
                      Text(field.value!,
                          style: context.label(11.5,
                              color: c.textDim, height: 1.45)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _inlineImageLink(String content) {
    final match = RegExp(
      r'https?://[^\s<>"]+\.(?:gif|png|jpe?g|webp)(?:\?[^\s<>"]*)?',
      caseSensitive: false,
    ).firstMatch(content);
    return match?.group(0);
  }

  Widget _inlineImage(BuildContext context, String url) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openImageViewer(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 260),
          child: AppImage(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.line),
              ),
              child: Text('Open media link',
                  style: context.label(11, color: c.accent)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateDivider(BuildContext context, DateTime? date) {
    final c = context.c;
    if (date == null) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(formatDay(date),
                style:
                    context.label(10, weight: FontWeight.w600, color: c.muted)),
          ),
          Expanded(child: Divider(color: c.line)),
        ],
      ),
    );
  }

  bool _needsDateDivider(Message previous, Message message) =>
      previous.createdAt == null ||
      message.createdAt == null ||
      !sameDay(previous.createdAt, message.createdAt);

  Widget _typingLine(BuildContext context, AppState state, Target target) {
    final names = state.typingNames(target);
    if (names.isEmpty) return const SizedBox.shrink();
    final text = names.length == 1
        ? '${names.first} is typing...'
        : names.length == 2
            ? '${names[0]} and ${names[1]} are typing...'
            : '${names.length} people are typing...';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 3, 18, 4),
      child: Row(
        children: [
          _typingDots(context),
          const SizedBox(width: 7),
          Text(text, style: context.label(10.5, color: context.c.muted)),
        ],
      ),
    );
  }

  Widget _typingDots(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: c.muted.withValues(alpha: 0.45 + index * 0.2),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  Widget _suggestionPopup(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 218),
      decoration: BoxDecoration(
        color: c.panel2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.lineStrong),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 18)],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return InkWell(
            onTap: () => _applySuggestion(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: switch (suggestion.kind) {
                        _SuggestionKind.user => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AppAvatar(
                                url: suggestion.user?.avatarUrl,
                                name: suggestion.label,
                                size: 26,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: PresenceDot(
                                  _state.presences[suggestion.id] ??
                                      suggestion.user?.status ??
                                      'offline',
                                  size: 8,
                                ),
                              ),
                            ],
                          ),
                        _SuggestionKind.role => Text(
                            '@',
                            style: TextStyle(
                              color:
                                  parseHex(suggestion.role?.color) ?? c.textDim,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        _SuggestionKind.channel => ChannelGlyph(
                            name: suggestion.channel?.icon,
                            color: suggestion.channel?.iconColor,
                            type: suggestion.channel?.type,
                            size: 15,
                          ),
                      },
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.kind == _SuggestionKind.channel
                              ? '#${suggestion.label}'
                              : suggestion.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(12.5, weight: FontWeight.w600),
                        ),
                        Text(
                          suggestion.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label(10, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _composerBar(BuildContext context, AppState state, Target target) {
    final c = context.c;
    final channel = target.isChannel && target.serverId != null
        ? state.channelById(target.serverId!, target.channelId!)
        : null;
    final canSend = !target.isChannel || state.can(Permission.sendMessages);
    final canAttach = !target.isChannel || state.can(Permission.attachFiles);
    final length = _composer.text.length;
    final limit = 4000;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.chat,
          border: Border(top: BorderSide(color: c.line)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_editing != null)
              _composerBanner(
                context,
                title: 'Editing message',
                body: _editing!.content,
                color: c.yellow,
                onCancel: () => setState(() {
                  _editing = null;
                  _composer.clear();
                }),
              ),
            if (_reply != null)
              _composerBanner(
                context,
                title: 'Replying to ${_reply!.authorName}',
                body: _reply!.content,
                color: c.accent,
                onCancel: () => setState(() => _reply = null),
              ),
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final attachment in _attachments)
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
                        decoration: BoxDecoration(
                          color: c.panel2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon('paperclip',
                                size: 12, color: Color(0xFF9BA3B0)),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                attachment.fileName ?? 'Attachment',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.label(11),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(
                                  () => _attachments.remove(attachment)),
                              icon: const Icon(Icons.close_rounded, size: 13),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 26, minHeight: 26),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (_suggestions.isNotEmpty) _suggestionPopup(context),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canAttach)
                  IconButton(
                    onPressed: _uploading ? null : _pickAttachments,
                    tooltip: 'Attach files',
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const AppIcon('plus', size: 19),
                  ),
                Expanded(
                  child: TextField(
                    controller: _composer,
                    focusNode: _focus,
                    enabled: canSend,
                    minLines: 1,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: _onComposerChanged,
                    onSubmitted: (_) => _send(),
                    style: context.label(13.5, height: 1.45),
                    decoration: InputDecoration(
                      hintText: canSend
                          ? (target.isChannel
                              ? 'Message #${target.title ?? ''}'
                              : 'Message ${target.title ?? ''}')
                          : 'You do not have permission to send messages',
                      filled: true,
                      fillColor: c.input,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: c.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: c.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide:
                            BorderSide(color: c.accent.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canSend ? _insertEmoji : null,
                  tooltip: 'Emoji',
                  icon: const AppIcon('smile', size: 19),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FilledButton(
                      onPressed: (!canSend || _sending) ? null : _send,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded,
                              size: 19, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (channel?.slowmodeSeconds != null &&
                    channel!.slowmodeSeconds! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: Text(
                      'Slow mode: one message every ${formatSlowmode(channel.slowmodeSeconds!)}',
                      style: context.label(9.5, color: c.muted),
                    ),
                  ),
                const Spacer(),
                if (state.prefs.characterCounter && length > limit * 0.8)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Text(
                      '$length / $limit',
                      style: context.label(
                        9.5,
                        color: length >= limit ? c.danger : c.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composerBanner(
    BuildContext context, {
    required String title,
    required String body,
    required Color color,
    required VoidCallback onCancel,
  }) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(9, 6, 4, 6),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(9),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.label(10.5,
                        weight: FontWeight.w700, color: color)),
                if (body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      truncateText(body, 120),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.label(11, color: c.muted),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 15),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
