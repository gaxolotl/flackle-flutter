import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'api.dart';
import 'format.dart';
import 'models.dart';
import 'notification_store.dart';
import 'permissions.dart';
import 'prefs.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.target,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final Target? target;
  final DateTime createdAt;
  bool read = false;
}

class AppState extends ChangeNotifier {
  AppState(this.client, this.prefs);

  final FlackleClient client;
  final AppPrefs prefs;

  SelfUser? me;
  List<Server> servers = const [];
  List<ServerFolder> serverFolders = const [];
  List<Conversation> conversations = const [];
  final Map<String, ChannelBundle> bundles = {};
  final Map<String, String> serverPermissions = {};
  final Map<String, String> channelPermissions = {};
  final Map<String, List<Member>> members = {};
  final Map<String, List<Role>> roles = {};
  final Map<String, ServerUserSettings> serverSettings = {};
  final Map<String, UnreadChannel> unread = {};
  final Map<String, Map<String, DateTime>> typing = {};
  final Map<String, String> presences = {};
  final Map<String, User> userCache = {};
  final List<AppNotification> notifications = [];
  final Set<String> savedMediaUrls = {};

  List<User> friends = const [];
  List<User> blocked = const [];
  FriendRequests friendRequests = const FriendRequests();

  Target? _active;
  int _activeRevision = 0;
  Target? get active => _active;
  set active(Target? target) {
    _active = target;
    _activeRevision++;
  }

  /// Distinguishes reopening a target from unrelated data or presence updates.
  int get activeRevision => _activeRevision;
  List<Message> messages = const [];

  /// One-shot requests to reveal a message after its channel finishes loading.
  final Map<String, String> messageFocusRequests = {};
  bool hasMoreBefore = false;
  bool loadingMessages = false;
  bool loadingOlder = false;
  String? messagesError;
  String? newMessagesMarkerId;

  bool loading = true;
  String? error;
  GatewayStatus gateway = GatewayStatus.offline;
  bool appInForeground = true;
  void Function(Message message, Target target, String title, String body)?
      onNotify;

  StreamSubscription<GatewayEvent>? _eventSubscription;
  StreamSubscription<GatewayStatus>? _statusSubscription;
  Timer? _typingTicker;
  Timer? _typingDebounce;
  Timer? _typingStop;
  Timer? _unreadRefresh;
  final Set<String> _loadingMembers = {};
  final Set<String> _loadingRoles = {};
  final Set<String> _previewLoads = {};

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> start() async {
    await _bindStreams();
    await _restoreNotificationHistory();
    await bootstrap();
  }

  Future<void> _bindStreams() async {
    _eventSubscription ??= client.events.listen(_onEvent);
    _statusSubscription ??= client.statusStream.listen((status) {
      if (_disposed) return;
      gateway = status;
      notifyListeners();
    });
    _typingTicker ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (_typingTimeoutCheck()) notifyListeners();
    });
    _unreadRefresh ??= Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(refreshUnread());
    });
  }

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await client.bootstrap();
      me = data['me'] as SelfUser;
      userCache[me!.id] = me!;
      servers = data['servers'] as List<Server>;
      serverFolders = data['folders'] as List<ServerFolder>;
      conversations = data['conversations'] as List<Conversation>;
      _cacheConversationMembers();
      serverSettings.clear();
      for (final entry in data['server_settings'] as List<ServerUserSettings>) {
        serverSettings[entry.serverId] = entry;
      }
      unread.clear();
      for (final entry in (data['unread'] as UnreadSummary).channels) {
        unread[entry.channelId] = entry;
      }
      loading = false;
      notifyListeners();
      unawaited(client
          .connect(servers.map((server) => server.id).toList())
          .catchError((Object _) {}));
      unawaited(loadSavedMedia());
      if (servers.isNotEmpty) {
        final first = servers.first;
        final settings = serverSettings[first.id];
        await selectServer(first.id,
            preferredChannelId: settings?.lastViewedChannelId);
      } else if (conversations.isNotEmpty) {
        await openConversation(conversations.first);
      }
    } catch (failure) {
      loading = false;
      error = failure.toString();
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    try {
      final results = await Future.wait([
        client.fetchServers(),
        client.fetchConversations(),
        client.fetchUnread(),
        client.fetchServerPreferences(),
      ]);
      servers = results[0] as List<Server>;
      conversations = results[1] as List<Conversation>;
      final summary = results[2] as UnreadSummary;
      final preferences = results[3] as ServerPreferences;
      serverFolders = preferences.folders;
      serverSettings
        ..clear()
        ..addEntries(preferences.settings
            .map((entry) => MapEntry(entry.serverId, entry)));
      unread
        ..clear()
        ..addEntries(
            summary.channels.map((entry) => MapEntry(entry.channelId, entry)));
      for (final server in servers) {
        bundles.remove(server.id);
      }
      if (active?.serverId != null) {
        await loadBundle(active!.serverId!, force: true);
      }
      notifyListeners();
    } catch (failure) {
      error = failure.toString();
      notifyListeners();
    }
  }

  Future<void> refreshUnread() async {
    try {
      final summary = await client.fetchUnread();
      unread
        ..clear()
        ..addEntries(
            summary.channels.map((entry) => MapEntry(entry.channelId, entry)));
      notifyListeners();
    } catch (_) {
      // Unread counts are advisory; keep the last known values.
    }
  }

  Future<void> refreshMe() async {
    try {
      final user = await client.fetchMe();
      me = user;
      userCache[user.id] = user;
      notifyListeners();
    } catch (_) {
      // Keep the current profile when the network is unavailable.
    }
  }

  Future<void> setMyStatus(String status) async {
    await client.setStatus(status);
    if (me != null) {
      presences[me!.id] = status == 'offline' ? 'invisible' : status;
    }
    notifyListeners();
    await refreshMe();
  }

  Future<void> refreshConversations() async {
    try {
      conversations = await client.fetchConversations();
      _cacheConversationMembers();
      notifyListeners();
    } catch (_) {
      // The current list stays usable offline.
    }
  }

  void _cacheConversationMembers() {
    for (final conversation in conversations) {
      for (final member in conversation.members) {
        userCache[member.user.id] = member.user;
      }
    }
  }

  Future<void> loadSavedMedia() async {
    try {
      savedMediaUrls
        ..clear()
        ..addAll(await client.fetchSavedMediaUrls());
      notifyListeners();
    } catch (_) {
      // Saving still works without the initial list.
    }
  }

  Future<bool> toggleSavedMedia(String url) async {
    final currentlySaved = savedMediaUrls.contains(url);
    final saved = await client.saveMedia(url, saved: !currentlySaved);
    if (saved) {
      savedMediaUrls.add(url);
    } else {
      savedMediaUrls.remove(url);
    }
    notifyListeners();
    return saved;
  }

  Future<void> removeConversation(String id) async {
    conversations = conversations.where((entry) => entry.id != id).toList();
    if (active?.conversationId == id) {
      active = null;
      messages = const [];
    }
    notifyListeners();
    unawaited(refreshConversations());
  }

  Future<void> logout() async {
    await client.logout();
    messages = const [];
    active = null;
    bundles.clear();
    unread.clear();
    typing.clear();
    presences.clear();
    notifications.clear();
    me = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _eventSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingTicker?.cancel();
    _typingDebounce?.cancel();
    _typingStop?.cancel();
    _unreadRefresh?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Future<void> selectServer(String serverId,
      {String? preferredChannelId}) async {
    await loadBundle(serverId);
    final bundle = bundles[serverId];
    if (bundle == null || bundle.channels.isEmpty) {
      notifyListeners();
      return;
    }
    unawaited(_loadServerPermissions(serverId));
    unawaited(loadMembers(serverId));
    final settings = serverSettings[serverId];
    final preferred = preferredChannelId ?? settings?.lastViewedChannelId;
    final choice = bundle.channels.firstWhere(
      (channel) =>
          channel.id == preferred &&
          channel.isText &&
          _canServer(serverId, Permission.viewChannel, channelId: channel.id),
      orElse: () => bundle.channels.firstWhere(
        (channel) =>
            channel.isText &&
            _canServer(serverId, Permission.viewChannel, channelId: channel.id),
        orElse: () => bundle.channels.first,
      ),
    );
    await selectChannel(serverId, choice);
  }

  Future<void> loadBundle(String serverId, {bool force = false}) async {
    if (bundles.containsKey(serverId) && !force) return;
    try {
      final bundle = await client.fetchChannels(serverId);
      bundles[serverId] = bundle;
      for (final channel in bundle.channels) {
        final value = bundle.permissions[channel.id];
        if (value != null) channelPermissions[channel.id] = value;
      }
      notifyListeners();
    } catch (failure) {
      error = failure.toString();
      notifyListeners();
    }
  }

  Future<void> reloadBundle(String serverId) =>
      loadBundle(serverId, force: true);

  Future<void> selectChannel(String serverId, Channel channel) async {
    final server = serverById(serverId);
    final target = Target.channelView(
      serverId: serverId,
      serverName: server?.name ?? 'Server',
      channelId: channel.id,
      title: channel.name,
      topic: channel.topic,
      channelType: channel.type,
      icon: channel.icon,
      iconColor: channel.iconColor,
    );
    if (channel.isStats) {
      active = target;
      messages = const [];
      notifyListeners();
      return;
    }
    await _openTarget(target);
  }

  Future<void> openConversation(Conversation conversation) async {
    final target = Target.conversation(
      conversation.id,
      title: conversation.titleFor(me?.id ?? ''),
    );
    await _openTarget(target);
  }

  Future<void> _openTarget(Target target) async {
    active = target;
    messages = const [];
    hasMoreBefore = false;
    loadingOlder = false;
    messagesError = null;
    newMessagesMarkerId = null;
    notifyListeners();
    try {
      unawaited(_loadChannelPermissions(target));
      await loadMessages();
      if (target.isChannel) {
        unawaited(client.updateServerUserSettings(
          target.serverId!,
          {'last_viewed_channel_id': target.channelId},
        ).catchError((Object _) {}));
        final settings = serverSettings[target.serverId!];
        if (settings != null) {
          serverSettings[target.serverId!] =
              settings.copyWith(lastViewedChannelId: target.channelId);
        }
      } else {
        final index = conversations
            .indexWhere((entry) => entry.id == target.conversationId);
        if (index != -1) {
          final entry = conversations[index];
          conversations = List.of(conversations)
            ..[index] = Conversation(
              id: entry.id,
              type: entry.type,
              name: entry.name,
              iconUrl: entry.iconUrl,
              isMuted: entry.isMuted,
              lastMessageAt: entry.lastMessageAt,
              lastMessage: entry.lastMessage,
              members: entry.members,
              unreadCount: 0,
            );
        }
      }
      notifyListeners();
    } catch (_) {
      // `loadMessages` reports its own error state.
    }
  }

  Future<void> _loadChannelPermissions(Target target) async {
    if (!target.isChannel) return;
    try {
      channelPermissions[target.channelId!] = await client
          .fetchChannelPermissions(target.serverId!, target.channelId!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadServerPermissions(String serverId) async {
    try {
      serverPermissions[serverId] =
          await client.fetchServerPermissions(serverId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMessages({bool quiet = false}) async {
    final target = active;
    if (target == null) return;
    if (!quiet) {
      loadingMessages = true;
      messagesError = null;
      notifyListeners();
    }
    try {
      final page = await client.fetchMessages(target);
      if (_disposed || active?.key != target.key) return;
      final visible =
          page.messages.where((message) => message.isRenderable).toList();
      messages = visible;
      hasMoreBefore = page.hasMoreBefore || page.hasMore;
      loadingMessages = false;
      messagesError = null;
      for (final message in visible) {
        final author = message.author;
        if (author != null) userCache[author.id] = author;
      }
      notifyListeners();
      _schedulePreviewBackfill(visible);
      final last = visible.isEmpty ? null : visible.last;
      if (last != null) {
        unawaited(client.markRead(target, last.id));
        if (target.isChannel) unread.remove(target.channelId);
      }
    } catch (failure) {
      if (_disposed) return;
      loadingMessages = false;
      if (!quiet) messagesError = failure.toString();
      notifyListeners();
    }
  }

  Future<void> loadOlder() async {
    final target = active;
    if (target == null || messages.isEmpty || !hasMoreBefore || loadingOlder) {
      return;
    }
    loadingOlder = true;
    try {
      final page =
          await client.fetchMessages(target, before: messages.first.id);
      if (active?.key != target.key) return;
      final older =
          page.messages.where((message) => message.isRenderable).toList();
      final known = messages.map((entry) => entry.id).toSet();
      messages = [
        ...older.where((message) => !known.contains(message.id)),
        ...messages,
      ];
      hasMoreBefore = page.hasMoreBefore || page.hasMore;
      notifyListeners();
    } catch (_) {
      // Keep the current page; the button remains available for a retry.
    } finally {
      loadingOlder = false;
    }
  }

  void requestMessageFocus(Target target, String messageId) {
    messageFocusRequests[target.key] = messageId;
  }

  String? takeMessageFocusRequest(Target target) =>
      messageFocusRequests.remove(target.key);

  /// Loads the page surrounding a message that may no longer be cached.
  /// Returns false when the message no longer exists.
  Future<bool> jumpToMessage(String messageId) async {
    final target = active;
    if (target == null) return false;
    if (messages.any((message) => message.id == messageId)) return true;
    try {
      final page = await client.fetchMessagesAround(target, messageId);
      if (active?.key != target.key) return false;
      final visible =
          page.messages.where((message) => message.isRenderable).toList();
      if (!visible.any((message) => message.id == messageId)) return false;
      messages = visible;
      hasMoreBefore = page.hasMoreBefore || page.hasMore;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearServer(String serverId) {
    bundles.remove(serverId);
    serverPermissions.remove(serverId);
    members.remove(serverId);
    roles.remove(serverId);
    if (active?.serverId == serverId) {
      active = null;
      messages = const [];
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sending and message actions
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(
    String content, {
    List<Attachment> attachments = const [],
    String? replyTo,
    bool suppressReplyMention = false,
    List<String> suppressEmbeds = const [],
  }) async {
    final target = active;
    if (target == null) return;
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final me = this.me;
    final optimistic = Message(
      id: 'local-$nonce',
      content: content,
      type: 'text',
      isDeleted: false,
      createdAt: DateTime.now(),
      nonce: nonce,
      sender: me,
      senderId: me?.id,
      attachments: attachments,
      embeds: suppressEmbeds
          .map((url) => Embed(url: url, type: 'suppressed'))
          .toList(),
      replyTo: replyTo == null ? null : _replyFor(replyTo),
      pending: true,
    );
    messages = [...messages, optimistic];
    notifyListeners();
    try {
      final message = await client.sendMessage(
        target,
        content,
        attachments: attachments,
        replyTo: replyTo,
        suppressReplyMention: suppressReplyMention,
        nonce: nonce,
        suppressEmbeds: suppressEmbeds,
      );
      _replacePending(nonce, message);
      final merged = messages.firstWhereOrNull(
          (entry) => entry.nonce == nonce || entry.id == message.id);
      if (merged != null) unawaited(_loadLinkPreviews(merged));
    } catch (failure) {
      messages = messages
          .map((entry) => entry.nonce == nonce ? _markFailed(entry) : entry)
          .toList();
      notifyListeners();
      rethrow;
    }
  }

  MessageReply? _replyFor(String messageId) {
    for (final entry in messages) {
      if (entry.id == messageId) {
        return MessageReply(
          id: entry.id,
          content: entry.content,
          senderId: entry.author?.id ?? '',
          senderUsername: entry.author?.username,
          senderDisplayName: entry.author?.name,
          senderAvatarUrl: entry.author?.avatarUrl,
        );
      }
    }
    return null;
  }

  void _replacePending(String nonce, Message message) {
    final index = messages.indexWhere((entry) => entry.nonce == nonce);
    if (index == -1) {
      if (!messages.any((entry) => entry.id == message.id)) {
        messages = [...messages, message];
      }
    } else {
      messages = List.of(messages)
        ..[index] = _mergeSent(messages[index], message);
    }
    notifyListeners();
  }

  /// Gateway acks carry the new message id but not the author, so keep the
  /// optimistic row's local details when confirming a send.
  Message _mergeSent(Message local, Message confirmed) => Message(
        id: confirmed.id.isEmpty ? local.id : confirmed.id,
        content: confirmed.content.isEmpty ? local.content : confirmed.content,
        type: confirmed.type,
        isDeleted: confirmed.isDeleted,
        createdAt: confirmed.createdAt ?? local.createdAt,
        updatedAt: confirmed.updatedAt,
        editedAt: confirmed.editedAt,
        conversationId: confirmed.conversationId ?? local.conversationId,
        nonce: confirmed.nonce ?? local.nonce,
        sender: confirmed.sender ?? local.sender,
        senderId: confirmed.senderId ?? local.senderId,
        senderUsername: confirmed.senderUsername ?? local.senderUsername,
        senderDisplayName:
            confirmed.senderDisplayName ?? local.senderDisplayName,
        senderAvatarUrl: confirmed.senderAvatarUrl ?? local.senderAvatarUrl,
        attachments: confirmed.attachments.isEmpty
            ? local.attachments
            : confirmed.attachments,
        embeds: confirmed.embeds.isEmpty ? local.embeds : confirmed.embeds,
        replyTo: confirmed.replyTo ?? local.replyTo,
        reactions: confirmed.reactions,
        mentionIds: confirmed.mentionIds,
        mentionEveryone: confirmed.mentionEveryone,
      );

  Message _markFailed(Message message) => Message(
        id: message.id,
        content: message.content,
        type: message.type,
        isDeleted: message.isDeleted,
        createdAt: message.createdAt,
        sender: message.sender,
        senderId: message.senderId,
        attachments: message.attachments,
        replyTo: message.replyTo,
        nonce: message.nonce,
        failed: true,
      );

  Future<void> editMessage(Message message, String content) async {
    final target = active;
    if (target == null) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed == message.content) return;
    final previous = messages;
    messages = _updateReplyPreviews(
      messages
          .map((entry) => entry.id == message.id
              ? entry.copyWith(content: trimmed, editedAt: DateTime.now())
              : entry)
          .toList(),
      message.id,
      content: trimmed,
    );
    final updated =
        messages.firstWhereOrNull((entry) => entry.id == message.id);
    notifyListeners();
    try {
      await client.editMessage(target, message.id, trimmed);
      if (updated != null) unawaited(_loadLinkPreviews(updated));
    } catch (failure) {
      messages = previous;
      notifyListeners();
      rethrow;
    }
  }

  /// Reply previews carry a snapshot of the original message. When that
  /// message changes, refresh every preview too, even when the original itself
  /// is outside the currently loaded page.
  List<Message> _updateReplyPreviews(
    List<Message> list,
    String messageId, {
    String? content,
    bool? deleted,
  }) {
    if (content == null && deleted == null) return list;
    return list.map((entry) {
      final reply = entry.replyTo;
      if (reply == null || reply.id != messageId) return entry;
      return entry.copyWith(
        replyTo: reply.copyWith(content: content, deleted: deleted),
      );
    }).toList();
  }

  Future<void> removeLinkPreview(Message message, String url) async {
    final target = active;
    if (target == null || message.id.startsWith('local-')) return;
    final previous = messages;
    messages = messages
        .map((entry) => entry.id == message.id
            ? entry.copyWith(
                embeds: entry.embeds
                    .map((embed) => _suppressEmbedUrl(embed, url))
                    .toList(),
              )
            : entry)
        .toList();
    notifyListeners();
    try {
      await client.removeMessageEmbed(target, message.id, url);
    } catch (failure) {
      messages = previous;
      notifyListeners();
      rethrow;
    }
  }

  Embed _suppressEmbedUrl(Embed embed, String url) {
    if (embed.url == url && (embed.isLinkPreview || embed.isSuppressed)) {
      return Embed(url: url, type: 'suppressed');
    }
    if (embed.nested.isEmpty) return embed;
    return embed.copyWith(
      nested:
          embed.nested.map((nested) => _suppressEmbedUrl(nested, url)).toList(),
    );
  }

  void _collectEmbedUrls(Embed embed, Set<String> urls) {
    final url = embed.url;
    if (url != null && url.isNotEmpty) urls.add(url);
    for (final nested in embed.nested) {
      _collectEmbedUrls(nested, urls);
    }
  }

  Future<void> _loadLinkPreviews(Message message) async {
    if (_disposed || !prefs.linkPreviews) return;
    final target = active;
    if (target == null ||
        message.id.isEmpty ||
        message.id.startsWith('local-') ||
        message.id.startsWith('pending-') ||
        message.type == 'system') {
      return;
    }
    final urls = suppressEmbedUrls(message.content);
    if (urls.isEmpty) return;
    final known = <String>{};
    for (final embed in message.embeds) {
      _collectEmbedUrls(embed, known);
    }
    final missing = urls.where((url) => !known.contains(url)).take(5).toList();
    if (missing.isEmpty) return;
    final key = '${message.id}:${missing.join('|')}';
    if (!_previewLoads.add(key)) return;
    try {
      final tokens = <String>[];
      final previews = <Embed>[];
      for (final url in missing) {
        try {
          final data = await client.createLinkPreview(url);
          final token = asStringOrNull(data['token']);
          final preview = asMap(data['preview']);
          if (token == null || preview.isEmpty) continue;
          final embed = Embed.fromJson(preview);
          if (embed.isEmpty) continue;
          tokens.add(token);
          previews.add(embed);
        } catch (_) {
          // A single unreachable preview should not block the others.
        }
      }
      if (tokens.isEmpty || _disposed) return;
      await client.updateMessageEmbeds(target, message.id, tokens);
      if (_disposed) return;
      final index = messages.indexWhere((entry) => entry.id == message.id);
      if (index == -1) return;
      final current = messages[index];
      final currentUrls = <String>{};
      for (final embed in current.embeds) {
        _collectEmbedUrls(embed, currentUrls);
      }
      final contentUrls = suppressEmbedUrls(current.content).toSet();
      final additions = previews
          .where((embed) =>
              contentUrls.contains(embed.url) &&
              !currentUrls.contains(embed.url))
          .toList();
      if (additions.isEmpty) return;
      messages = List.of(messages)
        ..[index] = current.copyWith(embeds: [...current.embeds, ...additions]);
      notifyListeners();
    } finally {
      _previewLoads.remove(key);
    }
  }

  void _schedulePreviewBackfill(List<Message> list) {
    var count = 0;
    for (final message in list.reversed) {
      if (count >= 8) break;
      if (message.embeds.isNotEmpty) continue;
      if (suppressEmbedUrls(message.content).isEmpty) continue;
      count += 1;
      unawaited(_loadLinkPreviews(message));
    }
  }

  Future<void> deleteMessage(Message message) async {
    final target = active;
    if (target == null) return;
    final previous = messages;
    messages = messages.where((entry) => entry.id != message.id).toList();
    notifyListeners();
    try {
      await client.deleteMessage(target, message.id);
    } catch (failure) {
      messages = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleReaction(Message message, String emoji) async {
    final target = active;
    if (target == null) return;
    final mine = message.reactions
        .where((reaction) => reaction.emoji == emoji)
        .any((reaction) => reaction.me);
    _applyReaction(message.id, emoji,
        added: !mine, userId: me?.id, count: null);
    try {
      if (mine) {
        await client.unreact(target, message.id, emoji);
      } else {
        await client.react(target, message.id, emoji);
      }
    } catch (failure) {
      _applyReaction(message.id, emoji,
          added: mine, userId: me?.id, count: null);
      rethrow;
    }
  }

  void _applyReaction(
    String messageId,
    String emoji, {
    bool added = true,
    String? userId,
    int? count,
  }) {
    messages = messages.map((message) {
      if (message.id != messageId) return message;
      final reactions = List<Reaction>.of(message.reactions);
      final index = reactions.indexWhere((reaction) => reaction.emoji == emoji);
      final mine = userId != null && userId == me?.id;
      if (index == -1) {
        if (added) {
          reactions.add(Reaction(emoji: emoji, count: count ?? 1, me: mine));
        }
      } else {
        final current = reactions[index];
        final nextCount =
            count ?? (current.count + (added ? 1 : -1)).clamp(0, 9999).toInt();
        if (nextCount <= 0) {
          reactions.removeAt(index);
        } else {
          reactions[index] = current.copyWith(
            count: nextCount,
            me: mine ? added : current.me,
          );
        }
      }
      return message.copyWith(reactions: reactions);
    }).toList();
    notifyListeners();
  }

  void notifyTyping() {
    final target = active;
    if (target == null || !isConnected) return;
    if (_typingDebounce?.isActive ?? false) return;
    _typingDebounce = Timer(const Duration(seconds: 4), () {});
    unawaited(client.sendTyping(target).catchError((Object _) {}));
  }

  void stopTyping() {
    final target = active;
    if (target == null) return;
    _typingStop?.cancel();
    unawaited(client.stopTyping(target).catchError((Object _) {}));
  }

  // ---------------------------------------------------------------------------
  // Members, roles, permissions
  // ---------------------------------------------------------------------------

  Future<void> loadMembers(String serverId, {bool force = false}) async {
    if ((members.containsKey(serverId) && !force) ||
        _loadingMembers.contains(serverId)) return;
    _loadingMembers.add(serverId);
    try {
      final list = await client.fetchMembers(serverId);
      members[serverId] = list;
      for (final member in list) {
        userCache[member.user.id] = member.user;
      }
      notifyListeners();
    } catch (_) {
      // Members are cached on a best-effort basis.
    } finally {
      _loadingMembers.remove(serverId);
    }
  }

  Future<void> loadRoles(String serverId, {bool force = false}) async {
    if ((roles.containsKey(serverId) && !force) ||
        _loadingRoles.contains(serverId)) return;
    _loadingRoles.add(serverId);
    try {
      final response = await client.fetchRoles(serverId);
      roles[serverId] = response.roles;
      notifyListeners();
    } catch (_) {
      // Roles are cached on a best-effort basis.
    } finally {
      _loadingRoles.remove(serverId);
    }
  }

  Future<void> loadFriends() async {
    final results = await Future.wait([
      client.fetchFriends(),
      client.fetchBlocked(),
      client.fetchFriendRequests(),
    ]);
    friends = results[0] as List<User>;
    blocked = results[1] as List<User>;
    friendRequests = results[2] as FriendRequests;
    notifyListeners();
  }

  bool _canServer(String serverId, int permission, {String? channelId}) {
    if (channelId != null) {
      final channelValue = channelPermissions[channelId];
      if (channelValue != null) return Permission.has(channelValue, permission);
    }
    final value = serverPermissions[serverId] ?? '0';
    return Permission.has(value, permission);
  }

  bool can(int permission, {String? serverId, String? channelId}) {
    final target = active;
    final resolvedServer = serverId ?? target?.serverId;
    if (resolvedServer == null) return false;
    return _canServer(resolvedServer, permission,
        channelId: channelId ?? target?.channelId);
  }

  bool get isConnected => gateway == GatewayStatus.connected;

  Role? roleById(String serverId, String roleId) {
    for (final role in roles[serverId] ?? const <Role>[]) {
      if (role.id == roleId) return role;
    }
    return null;
  }

  User? userById(String id) => userCache[id];

  Member? memberById(String serverId, String id) {
    for (final member in members[serverId] ?? const <Member>[]) {
      if (member.id == id) return member;
    }
    return null;
  }

  List<Member> membersFor(String serverId) {
    final list = List<Member>.of(members[serverId] ?? const <Member>[]);
    list.sort((a, b) {
      final aOwner = a.isOwner ? 0 : 1;
      final bOwner = b.isOwner ? 0 : 1;
      if (aOwner != bOwner) return aOwner.compareTo(bOwner);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return list;
  }

  Server? serverById(String serverId) {
    for (final server in servers) {
      if (server.id == serverId) return server;
    }
    return null;
  }

  Channel? channelById(String serverId, String channelId) {
    for (final channel in bundles[serverId]?.channels ?? const <Channel>[]) {
      if (channel.id == channelId) return channel;
    }
    return null;
  }

  List<Category> categoriesFor(String serverId) =>
      bundles[serverId]?.categories ?? const [];

  List<Channel> channelsFor(String serverId) =>
      bundles[serverId]?.channels ?? const [];

  List<Channel> visibleChannels(String serverId) => channelsFor(serverId)
      .where((channel) =>
          _canServer(serverId, Permission.viewChannel, channelId: channel.id))
      .toList();

  // ---------------------------------------------------------------------------
  // Unread and notifications
  // ---------------------------------------------------------------------------

  UnreadChannel? unreadForChannel(String channelId) => unread[channelId];

  int unreadForServer(String serverId) {
    var total = 0;
    for (final entry in unread.values) {
      if (entry.serverId == serverId) total += entry.unreadCount;
    }
    return total;
  }

  int mentionsForServer(String serverId) {
    var total = 0;
    for (final entry in unread.values) {
      if (entry.serverId == serverId) total += entry.mentionCount;
    }
    return total;
  }

  int get totalMentions =>
      unread.values.fold(0, (sum, entry) => sum + entry.mentionCount) +
      friendRequests.incoming.length;

  int get totalUnread =>
      unread.values.fold(0, (sum, entry) => sum + entry.unreadCount) +
      conversations.fold(0, (sum, entry) => sum + entry.unreadCount);

  void addNotification({
    required String title,
    required String body,
    Target? target,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: '${DateTime.now().microsecondsSinceEpoch}-${notifications.length}',
        title: title,
        body: body,
        target: target,
      ),
    );
    if (notifications.length > 60) notifications.removeLast();
    unawaited(NotificationStore.add(title: title, body: body, target: target));
    notifyListeners();
  }

  Future<void> _restoreNotificationHistory() async {
    final stored = await NotificationStore.load();
    if (stored.isEmpty || _disposed) return;
    final restored = <AppNotification>[];
    for (final entry in stored) {
      final rawTarget = asMap(entry['target']);
      Target? target;
      final serverId = asStringOrNull(rawTarget['server_id']);
      final channelId = asStringOrNull(rawTarget['channel_id']);
      final conversationId = asStringOrNull(rawTarget['conversation_id']);
      if (serverId != null && channelId != null) {
        target = Target.channelView(
          serverId: serverId,
          serverName: asString(rawTarget['server_name'], 'Server'),
          channelId: channelId,
          title: asString(rawTarget['title'], 'channel'),
          channelType: asString(rawTarget['channel_type'], 'text'),
          icon: asStringOrNull(rawTarget['icon']),
          iconColor: asStringOrNull(rawTarget['icon_color']),
        );
      } else if (conversationId != null) {
        target = Target.conversation(
          conversationId,
          title: asStringOrNull(rawTarget['title']) ?? 'Direct message',
        );
      }
      restored.add(AppNotification(
        id: 'stored-${restored.length}-${entry['created_at']}',
        title: asString(entry['title']),
        body: asString(entry['body']),
        target: target,
        createdAt: DateTime.tryParse(asString(entry['created_at'])),
      ));
    }
    notifications
      ..clear()
      ..addAll(restored);
    notifyListeners();
  }

  void markNotificationsRead() {
    for (final entry in notifications) {
      entry.read = true;
    }
    notifyListeners();
  }

  void markNotificationRead(AppNotification notification) {
    notification.read = true;
    notifyListeners();
  }

  void updateServerNotificationLevel(String serverId, String level) {
    if (_disposed) return;
    final current = serverSettings[serverId];
    serverSettings[serverId] = current == null
        ? ServerUserSettings(serverId: serverId, notificationLevel: level)
        : current.copyWith(notificationLevel: level);
    notifyListeners();
  }

  int get unreadNotifications =>
      notifications.where((entry) => !entry.read).length;

  // ---------------------------------------------------------------------------
  // Gateway events
  // ---------------------------------------------------------------------------

  Future<void> _onEvent(GatewayEvent event) async {
    switch (event.type) {
      case 'message_create':
      case 'new_message':
      case 'channel_message':
        _handleMessageCreate(event);
        break;
      case 'message_update':
      case 'message_edited':
      case 'channel_message_edited':
        _handleMessageUpdate(event);
        break;
      case 'message_delete':
      case 'channel_message_deleted':
        _handleMessageDelete(event);
        break;
      case 'channel_messages_bulk_deleted':
        _handleBulkDelete(event);
        break;
      case 'message_reaction_added':
      case 'message_reaction_removed':
      case 'channel_message_reaction_added':
      case 'channel_message_reaction_removed':
        _handleReaction(event);
        break;
      case 'typing':
      case 'channel_typing':
        _handleTyping(event);
        break;
      case 'presence_update':
        final userId = asString(event.payload['user_id']);
        presences[userId] = asString(event.payload['status'], 'offline');
        notifyListeners();
        break;
      case 'channel_created':
      case 'channel_updated':
      case 'channel_deleted':
        final serverId = event.serverId ?? active?.serverId;
        if (serverId != null) await reloadBundle(serverId);
        break;
      case 'conversation_created':
      case 'conversation_updated':
      case 'conversation_hidden':
        conversations = await client.fetchConversations();
        notifyListeners();
        break;
      case 'guild_member_added':
      case 'member_added':
      case 'guild_member_removed':
      case 'member_removed':
      case 'member_left':
        final serverId = event.serverId ?? active?.serverId;
        if (serverId != null) unawaited(loadMembers(serverId, force: true));
        break;
      case 'friend_request_received':
      case 'friend_request_accepted':
        unawaited(loadFriends());
        break;
      case 'account_restricted':
        addNotification(
          title: 'Account restricted',
          body: 'Flackle restricted this account.',
        );
        break;
      default:
        break;
    }
  }

  void _handleMessageCreate(GatewayEvent event) {
    final payload = event.payload;
    final raw = payload['message'] is Map ? asMap(payload['message']) : payload;
    final message = Message.fromJson(raw);
    if (message.id.isEmpty) return;
    final serverId = event.serverId ?? asStringOrNull(raw['server_id']);
    final channelId = event.channelId ?? asStringOrNull(raw['channel_id']);
    final conversationId =
        event.conversationId ?? asStringOrNull(raw['conversation_id']);
    final author = message.sender;
    if (author != null) userCache[author.id] = author;
    final mentioned = message.mentionEveryone ||
        (me != null && message.mentionIds.contains(me!.id));
    final replied = message.replyTo?.senderId == me?.id;

    if (conversationId != null) {
      final index =
          conversations.indexWhere((entry) => entry.id == conversationId);
      if (index != -1) {
        final entry = conversations[index];
        final isActive = active?.conversationId == conversationId;
        conversations = List.of(conversations)
          ..[index] = Conversation(
            id: entry.id,
            type: entry.type,
            name: entry.name,
            iconUrl: entry.iconUrl,
            isMuted: entry.isMuted,
            lastMessageAt: message.createdAt,
            lastMessage: message,
            members: entry.members,
            unreadCount: isActive ? 0 : entry.unreadCount + 1,
          );
      } else {
        unawaited(client.fetchConversations().then((value) {
          conversations = value;
          notifyListeners();
        }).catchError((Object _) {}));
      }
    }

    final belongsHere = active != null &&
        ((active!.isChannel && channelId == active!.channelId) ||
            (!active!.isChannel && conversationId == active!.conversationId));
    if (belongsHere) {
      final index = messages.indexWhere((entry) =>
          entry.id == message.id ||
          (message.nonce != null && entry.nonce == message.nonce));
      if (index == -1) {
        messages = [...messages, message];
      } else {
        messages = List.of(messages)..[index] = message;
      }
      notifyListeners();
      unawaited(_loadLinkPreviews(message));
      unawaited(client.markRead(active!, message.id));
      if (active!.isChannel) unread.remove(channelId);
    } else if (serverId != null && channelId != null) {
      final current = unread[channelId];
      unread[channelId] = UnreadChannel(
        serverId: serverId,
        channelId: channelId,
        unreadCount: (current?.unreadCount ?? 0) + 1,
        mentionCount: (current?.mentionCount ?? 0) + (mentioned ? 1 : 0),
      );
      final author = message.sender;
      if (author != null &&
          author.id != me?.id &&
          (mentioned || !prefs.mentionsOnly)) {
        addNotification(
          title: mentioned ? '${author.name} mentioned you' : author.name,
          body:
              message.content.isEmpty ? 'Sent an attachment' : message.content,
          target: Target.channelView(
            serverId: serverId,
            serverName: serverById(serverId)?.name ?? 'Server',
            channelId: channelId,
            title: channelById(serverId, channelId)?.name ?? 'channel',
            channelType: channelById(serverId, channelId)?.type ?? 'text',
          ),
        );
      }
    }
    _notifyMentionOrReply(
      message,
      author: author,
      mentioned: mentioned,
      replied: replied,
      serverId: serverId,
      channelId: channelId,
      conversationId: conversationId,
      belongsHere: belongsHere,
    );
    notifyListeners();
  }

  void _notifyMentionOrReply(
    Message message, {
    required User? author,
    required bool mentioned,
    required bool replied,
    required String? serverId,
    required String? channelId,
    required String? conversationId,
    required bool belongsHere,
  }) {
    final notify = onNotify;
    if (notify == null ||
        !prefs.notifications ||
        me == null ||
        author == null ||
        author.id == me!.id) {
      return;
    }
    if (appInForeground && belongsHere) return;

    final serverMuted = serverId != null &&
        serverSettings[serverId]?.notificationLevel == 'nothing';
    if (serverMuted) return;

    final conversation = conversationId == null
        ? null
        : conversations
            .where((entry) => entry.id == conversationId)
            .firstOrNull;
    if (conversation?.isMuted == true) return;

    // Direct and group conversations notify for every incoming message.
    // Server channels only notify for direct mentions, @everyone and replies.
    if (conversationId == null && !mentioned && !replied) return;

    final body =
        message.content.isEmpty ? 'Sent an attachment' : message.content;
    final String title;
    if (mentioned) {
      title = '${author.name} mentioned you';
    } else if (replied) {
      title = '${author.name} replied to you';
    } else {
      title = author.name;
    }

    final Target target;
    if (conversationId != null) {
      target = Target.conversation(
        conversationId,
        title: conversation?.titleFor(me!.id) ?? 'Direct message',
      );
    } else {
      target = Target.channelView(
        serverId: serverId!,
        serverName: serverById(serverId)?.name ?? 'Server',
        channelId: channelId!,
        title: channelById(serverId, channelId)?.name ?? 'channel',
        channelType: channelById(serverId, channelId)?.type ?? 'text',
      );
    }
    notify(message, target, title, body);
  }

  void _handleMessageUpdate(GatewayEvent event) {
    final raw = event.payload['message'] is Map
        ? asMap(event.payload['message'])
        : event.payload;
    final id = asString(
        event.payload['message_id'] ?? event.payload['id'] ?? raw['id']);
    final content = asString(raw['content']);
    if (id.isEmpty || content.isEmpty) return;
    final editedAt = asDate(raw['edited_at']) ??
        asDate(event.payload['edited_at']) ??
        DateTime.now();
    var updated = messages
        .map((entry) => entry.id == id
            ? entry.copyWith(content: content, editedAt: editedAt)
            : entry)
        .toList();
    updated =
        _updateReplyPreviews(updated, id, content: content, deleted: false);
    messages = updated;
    notifyListeners();
  }

  void _handleMessageDelete(GatewayEvent event) {
    final id = asString(event.payload['message_id'] ?? event.payload['id']);
    if (id.isEmpty) return;
    messages = _updateReplyPreviews(
      messages.where((entry) => entry.id != id).toList(),
      id,
      deleted: true,
    );
    notifyListeners();
  }

  void _handleBulkDelete(GatewayEvent event) {
    if (event.serverId != active?.serverId) return;
    final ids =
        asList(event.payload['message_ids']).map((value) => '$value').toSet();
    var updated = messages.where((entry) => !ids.contains(entry.id)).toList();
    for (final id in ids) {
      updated = _updateReplyPreviews(updated, id, deleted: true);
    }
    messages = updated;
    notifyListeners();
  }

  void _handleReaction(GatewayEvent event) {
    final id = asString(event.payload['message_id']);
    final emoji = asString(event.payload['emoji']);
    if (id.isEmpty || emoji.isEmpty) return;
    final added = event.type.contains('added');
    final count = asIntOrNull(event.payload['count']);
    _applyReaction(
      id,
      emoji,
      added: added,
      userId: asStringOrNull(event.payload['user_id']),
      count: count,
    );
  }

  void _handleTyping(GatewayEvent event) {
    final userId = asString(event.payload['user_id']);
    if (userId.isEmpty) return;
    final isTyping = asBool(event.payload['is_typing']);
    final key = event.conversationId != null
        ? 'd:${event.conversationId}'
        : 'g:${event.serverId}:${event.channelId}';
    final map = typing.putIfAbsent(key, () => {});
    if (isTyping) {
      map[userId] = DateTime.now().add(const Duration(seconds: 6));
    } else {
      map.remove(userId);
    }
    notifyListeners();
  }

  bool _typingTimeoutCheck() {
    var changed = false;
    final now = DateTime.now();
    for (final entry in typing.entries) {
      final expired = entry.value.entries
          .where((item) => item.value.isBefore(now))
          .map((item) => item.key)
          .toList();
      for (final id in expired) {
        entry.value.remove(id);
        changed = true;
      }
    }
    return changed;
  }

  List<String> typingNames(Target target) {
    final map = typing[target.key];
    if (map == null || map.isEmpty) return const [];
    final names = <String>[];
    for (final id in map.keys) {
      if (id == me?.id) continue;
      final member =
          target.serverId == null ? null : memberById(target.serverId!, id);
      final user = member?.user ?? userCache[id];
      if (user != null) names.add(user.name);
    }
    return names;
  }

  String get destinationLabel {
    final target = active;
    if (target == null) return 'Flackle';
    if (target.isChannel) {
      return '${target.serverName ?? 'Server'} · #${target.title ?? ''}';
    }
    return target.title ?? 'Direct message';
  }
}
