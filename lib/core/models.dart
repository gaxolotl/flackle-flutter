/// Flackle data models, mirroring `src/lib/types.ts` and
/// `crates/flackle-core/src/models.rs`.
library;

Map<String, dynamic> asMap(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, dynamic>{};

List<dynamic> asList(dynamic value) => value is List ? value : const [];

String asString(dynamic value, [String fallback = '']) =>
    value is String ? value : (value == null ? fallback : '$value');

String? asStringOrNull(dynamic value) =>
    value is String && value.isNotEmpty ? value : null;

int asInt(dynamic value, [int fallback = 0]) => value is num
    ? value.toInt()
    : (value is String ? int.tryParse(value) ?? fallback : fallback);

int? asIntOrNull(dynamic value) => value is num
    ? value.toInt()
    : (value is String ? int.tryParse(value) : null);

bool asBool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? asDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String? asColor(dynamic value) {
  final text = asStringOrNull(value);
  if (text == null) return null;
  return RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(text) ? text : null;
}

class User {
  const User({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.status,
    this.typingIndicatorEnabled,
    this.typingIndicatorText,
    this.typingIndicatorStyle,
    this.typingIndicatorEmojis,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? status;
  final bool? typingIndicatorEnabled;
  final String? typingIndicatorText;
  final String? typingIndicatorStyle;
  final List<String>? typingIndicatorEmojis;

  String get name {
    final display = displayName?.trim();
    return display != null && display.isNotEmpty ? display : username;
  }

  String get handle => '@$username';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: asString(json['id']),
        username: asString(json['username'], 'flackle'),
        displayName: asStringOrNull(json['display_name']),
        avatarUrl: asStringOrNull(json['avatar_url']),
        bannerUrl: asStringOrNull(json['banner_url']),
        status: asStringOrNull(json['status']),
        typingIndicatorEnabled: json['typing_indicator_enabled'] as bool?,
        typingIndicatorText: asStringOrNull(json['typing_indicator_text']),
        typingIndicatorStyle: asStringOrNull(json['typing_indicator_style']),
        typingIndicatorEmojis: (json['typing_indicator_emojis'] as List?)
            ?.whereType<String>()
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
        'status': status,
      };
}

class SelfUser extends User {
  const SelfUser({
    required super.id,
    required super.username,
    super.displayName,
    super.avatarUrl,
    super.bannerUrl,
    super.status,
    super.typingIndicatorEnabled,
    super.typingIndicatorText,
    super.typingIndicatorStyle,
    super.typingIndicatorEmojis,
    required this.email,
    required this.isAdmin,
  });

  final String email;
  final bool isAdmin;

  factory SelfUser.fromJson(Map<String, dynamic> json) {
    final base = User.fromJson(json);
    return SelfUser(
      id: base.id,
      username: base.username,
      displayName: base.displayName,
      avatarUrl: base.avatarUrl,
      bannerUrl: base.bannerUrl,
      status: base.status,
      typingIndicatorEnabled: base.typingIndicatorEnabled,
      typingIndicatorText: base.typingIndicatorText,
      typingIndicatorStyle: base.typingIndicatorStyle,
      typingIndicatorEmojis: base.typingIndicatorEmojis,
      email: asString(json['email']),
      isAdmin: asBool(json['is_admin']),
    );
  }
}

class Attachment {
  const Attachment({
    required this.url,
    this.fileName,
    this.fileSize,
    this.contentType,
    this.width,
    this.height,
    this.expiresAt,
    this.saved,
  });

  final String url;
  final String? fileName;
  final int? fileSize;
  final String? contentType;
  final double? width;
  final double? height;
  final String? expiresAt;
  final bool? saved;

  bool get isImage => (contentType ?? '').startsWith('image/');
  bool get isVideo => (contentType ?? '').startsWith('video/');
  bool get isAudio => (contentType ?? '').startsWith('audio/');

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        url: asString(json['url']),
        fileName: asStringOrNull(json['file_name']),
        fileSize: asIntOrNull(json['file_size']),
        contentType: asStringOrNull(json['content_type']),
        width: (json['width'] as num?)?.toDouble(),
        height: (json['height'] as num?)?.toDouble(),
        expiresAt: asStringOrNull(json['expires_at']),
        saved: json['saved'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'file_name': fileName,
        'file_size': fileSize,
        'content_type': contentType,
        'width': width,
        'height': height,
        'expires_at': expiresAt,
      };
}

class EmbedField {
  const EmbedField({this.name, this.value, this.inline = false});

  final String? name;
  final String? value;
  final bool inline;

  factory EmbedField.fromJson(Map<String, dynamic> json) => EmbedField(
        name: asStringOrNull(json['name']),
        value: asStringOrNull(json['value']),
        inline: asBool(json['inline']),
      );
}

class Embed {
  const Embed({
    this.url,
    this.title,
    this.description,
    this.type,
    this.color,
    this.siteName,
    this.providerName,
    this.imageUrl,
    this.thumbnailUrl,
    this.videoUrl,
    this.videoHlsUrl,
    this.faviconUrl,
    this.fields = const [],
    this.kind,
    this.code,
    this.serverId,
    this.serverName,
    this.serverIconUrl,
    this.memberCount,
    this.presenceCount,
    this.nested = const [],
  });

  final String? url;
  final String? title;
  final String? description;
  final String? type;
  final String? color;
  final String? siteName;
  final String? providerName;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? videoHlsUrl;
  final String? faviconUrl;
  final List<EmbedField> fields;
  final String? kind;
  final String? code;
  final String? serverId;
  final String? serverName;
  final String? serverIconUrl;
  final int? memberCount;
  final int? presenceCount;
  final List<Embed> nested;

  bool get isInvite => kind != null && (serverName != null || code != null);

  bool get isSuppressed => type == 'suppressed';

  bool get isLinkPreview =>
      !isSuppressed &&
      url != null &&
      (type == 'link' || type == 'twitter' || type == null);

  bool get hasCardContent =>
      !isSuppressed &&
      ((title?.isNotEmpty ?? false) ||
          (description?.isNotEmpty ?? false) ||
          imageUrl != null ||
          thumbnailUrl != null ||
          fields.isNotEmpty);

  bool get isEmpty => !isInvite && !hasCardContent && nested.isEmpty;

  Embed copyWith({List<Embed>? nested}) => Embed(
        url: url,
        title: title,
        description: description,
        type: type,
        color: color,
        siteName: siteName,
        providerName: providerName,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        videoUrl: videoUrl,
        videoHlsUrl: videoHlsUrl,
        faviconUrl: faviconUrl,
        fields: fields,
        kind: kind,
        code: code,
        serverId: serverId,
        serverName: serverName,
        serverIconUrl: serverIconUrl,
        memberCount: memberCount,
        presenceCount: presenceCount,
        nested: nested ?? this.nested,
      );

  factory Embed.fromJson(Map<String, dynamic> json) => Embed(
        url: asStringOrNull(
            json['url'] ?? json['providerUrl'] ?? json['titleUrl']),
        title: asStringOrNull(json['title']),
        description: asStringOrNull(json['description']),
        type: asStringOrNull(json['type']),
        color: (json['color'] ?? json['accentColor']) == null
            ? null
            : '${json['color'] ?? json['accentColor']}',
        siteName: asStringOrNull(json['site_name'] ?? json['siteName']),
        providerName:
            asStringOrNull(json['provider_name'] ?? json['providerName']),
        imageUrl: asStringOrNull(json['image_url'] ?? json['imageUrl']),
        thumbnailUrl:
            asStringOrNull(json['thumbnail_url'] ?? json['thumbnailUrl']),
        videoUrl: asStringOrNull(json['video_url'] ?? json['videoUrl']),
        videoHlsUrl:
            asStringOrNull(json['video_hls_url'] ?? json['videoHlsUrl']),
        faviconUrl: asStringOrNull(json['favicon_url'] ?? json['faviconUrl']),
        fields: asList(json['fields'])
            .whereType<Map>()
            .map((value) => EmbedField.fromJson(asMap(value)))
            .toList(),
        kind: asStringOrNull(json['kind']),
        code: asStringOrNull(json['code']),
        serverId: asStringOrNull(json['server_id']),
        serverName: asStringOrNull(json['server_name']),
        serverIconUrl: asStringOrNull(json['server_icon_url']),
        memberCount: asIntOrNull(json['approx_member_count']),
        presenceCount: asIntOrNull(json['approx_presence_count']),
        nested: asList(json['embeds'])
            .whereType<Map>()
            .map((value) => Embed.fromJson(asMap(value)))
            .where((value) => !value.isEmpty)
            .toList(),
      );
}

class Reaction {
  const Reaction({
    required this.emoji,
    required this.count,
    this.me = false,
    this.users = const [],
  });

  final String emoji;
  final int count;
  final bool me;
  final List<User> users;

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
        emoji: asString(json['emoji']),
        count: asInt(json['count']),
        me: asBool(json['me']),
        users: asList(json['users'])
            .whereType<Map>()
            .map((value) => User.fromJson(asMap(value)))
            .toList(),
      );

  Reaction copyWith({int? count, bool? me}) => Reaction(
        emoji: emoji,
        count: count ?? this.count,
        me: me ?? this.me,
        users: users,
      );
}

class MessageReply {
  const MessageReply({
    required this.id,
    required this.content,
    required this.senderId,
    this.senderUsername,
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.deleted = false,
  });

  final String id;
  final String content;
  final String senderId;
  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final bool deleted;

  String get authorName => (senderDisplayName?.trim().isNotEmpty ?? false)
      ? senderDisplayName!
      : (senderUsername ?? 'Unknown member');

  factory MessageReply.fromJson(Map<String, dynamic> json) => MessageReply(
        id: asString(json['id']),
        content: asString(json['content']),
        senderId: asString(json['sender_id']),
        senderUsername: asStringOrNull(json['sender_username']),
        senderDisplayName: asStringOrNull(json['sender_display_name']),
        senderAvatarUrl: asStringOrNull(json['sender_avatar_url']),
        deleted: asBool(json['deleted']),
      );

  MessageReply copyWith({
    String? content,
    String? senderDisplayName,
    String? senderAvatarUrl,
    bool? deleted,
  }) =>
      MessageReply(
        id: id,
        content: content ?? this.content,
        senderId: senderId,
        senderUsername: senderUsername,
        senderDisplayName: senderDisplayName ?? this.senderDisplayName,
        senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
        deleted: deleted ?? this.deleted,
      );
}

class Message {
  const Message({
    required this.id,
    required this.content,
    required this.type,
    required this.isDeleted,
    required this.createdAt,
    this.updatedAt,
    this.editedAt,
    this.conversationId,
    this.nonce,
    this.sender,
    this.senderId,
    this.senderUsername,
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.attachments = const [],
    this.embeds = const [],
    this.replyTo,
    this.reactions = const [],
    this.mentionIds = const [],
    this.mentionEveryone = false,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final String content;
  final String type;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? editedAt;
  final String? conversationId;
  final String? nonce;
  final User? sender;
  final String? senderId;
  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final List<Attachment> attachments;
  final List<Embed> embeds;
  final MessageReply? replyTo;
  final List<Reaction> reactions;
  final List<String> mentionIds;
  final bool mentionEveryone;
  final bool pending;
  final bool failed;

  User? get author =>
      sender ??
      (senderId == null
          ? null
          : User(
              id: senderId!,
              username: senderUsername ?? 'unknown',
              displayName: senderDisplayName,
              avatarUrl: senderAvatarUrl,
            ));

  String get authorName =>
      author?.name ?? senderDisplayName ?? senderUsername ?? 'Unknown member';

  bool get isSystem => type == 'system';

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawSender = json['sender'] ?? json['author'];
    final rawReply = json['reply_to'];
    return Message(
      id: asString(json['id']),
      content: asString(json['content']),
      type: asString(json['type'], 'text'),
      isDeleted: asBool(json['is_deleted']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      editedAt: asDate(json['edited_at']),
      conversationId: asStringOrNull(json['conversation_id']),
      nonce: asStringOrNull(json['nonce']),
      sender: rawSender is Map ? User.fromJson(asMap(rawSender)) : null,
      senderId: asStringOrNull(json['sender_id']),
      senderUsername: asStringOrNull(json['sender_username']),
      senderDisplayName: asStringOrNull(json['sender_display_name']),
      senderAvatarUrl: asStringOrNull(json['sender_avatar_url']),
      attachments: asList(json['attachments'])
          .whereType<Map>()
          .map((value) => Attachment.fromJson(asMap(value)))
          .toList(),
      embeds: asList(json['embeds'])
          .whereType<Map>()
          .map((value) => Embed.fromJson(asMap(value)))
          .toList(),
      replyTo: rawReply is Map ? MessageReply.fromJson(asMap(rawReply)) : null,
      reactions: asList(json['reactions'])
          .whereType<Map>()
          .map((value) => Reaction.fromJson(asMap(value)))
          .toList(),
      mentionIds: asList(json['mention_ids']).map((value) => '$value').toList(),
      mentionEveryone: asBool(json['mention_everyone']),
      pending: asBool(json['pending']),
      failed: asBool(json['failed']),
    );
  }

  Message copyWith({
    String? content,
    bool? isDeleted,
    DateTime? editedAt,
    MessageReply? replyTo,
    bool clearReply = false,
    List<Attachment>? attachments,
    List<Embed>? embeds,
    List<Reaction>? reactions,
    bool? pending,
    bool? failed,
  }) =>
      Message(
        id: id,
        content: content ?? this.content,
        type: type,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
        editedAt: editedAt ?? this.editedAt,
        conversationId: conversationId,
        nonce: nonce,
        sender: sender,
        senderId: senderId,
        senderUsername: senderUsername,
        senderDisplayName: senderDisplayName,
        senderAvatarUrl: senderAvatarUrl,
        attachments: attachments ?? this.attachments,
        embeds: embeds ?? this.embeds,
        replyTo: clearReply ? null : (replyTo ?? this.replyTo),
        reactions: reactions ?? this.reactions,
        mentionIds: mentionIds,
        mentionEveryone: mentionEveryone,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );

  bool get isRenderable {
    if (isDeleted) return false;
    if (type == 'system') return true;
    return content.isNotEmpty ||
        attachments.isNotEmpty ||
        embeds.isNotEmpty ||
        reactions.isNotEmpty;
  }
}

class Server {
  const Server({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.bannerUrl,
    this.ownerId,
    this.defaultNotificationLevel,
    this.position,
    this.memberCount,
    this.presenceCount,
    this.flags,
    this.verified,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? bannerUrl;
  final String? ownerId;
  final String? defaultNotificationLevel;
  final int? position;
  final int? memberCount;
  final int? presenceCount;
  final String? flags;
  final bool? verified;
  final DateTime? createdAt;

  factory Server.fromJson(Map<String, dynamic> json) => Server(
        id: asString(json['id']),
        name: asString(json['name'], 'Server'),
        description: asStringOrNull(json['description']),
        iconUrl: asStringOrNull(json['icon_url']),
        bannerUrl: asStringOrNull(json['banner_url']),
        ownerId: asStringOrNull(json['owner_id']),
        defaultNotificationLevel:
            asStringOrNull(json['default_notification_level']),
        position: asIntOrNull(json['position']),
        memberCount: asIntOrNull(json['approx_member_count']),
        presenceCount: asIntOrNull(json['approx_presence_count']),
        flags: asStringOrNull(json['flags']),
        verified: json['verified'] as bool?,
        createdAt: asDate(json['created_at']),
      );

  Server copyWith({
    String? name,
    String? description,
    String? defaultNotificationLevel,
    String? iconUrl,
  }) =>
      Server(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        iconUrl: iconUrl ?? this.iconUrl,
        bannerUrl: bannerUrl,
        ownerId: ownerId,
        defaultNotificationLevel:
            defaultNotificationLevel ?? this.defaultNotificationLevel,
        position: position,
        memberCount: memberCount,
        presenceCount: presenceCount,
        flags: flags,
        verified: verified,
        createdAt: createdAt,
      );
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.type,
    this.topic,
    this.position = 0,
    this.categoryId,
    this.slowmodeSeconds,
    this.icon,
    this.iconColor,
  });

  final String id;
  final String name;
  final String type;
  final String? topic;
  final int position;
  final String? categoryId;
  final int? slowmodeSeconds;
  final String? icon;
  final String? iconColor;

  bool get isText => type != 'voice' && type != 'stats';
  bool get isVoice => type == 'voice';
  bool get isStats => type == 'stats';

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: asString(json['id']),
        name: asString(json['name'], 'channel'),
        type: asString(json['type'], 'text'),
        topic: asStringOrNull(json['topic']),
        position: asIntOrNull(json['position']) ?? 0,
        categoryId: asStringOrNull(json['category_id']),
        slowmodeSeconds: asIntOrNull(json['slowmode_seconds']),
        icon: asStringOrNull(json['icon']),
        iconColor: asColor(json['icon_color']),
      );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    this.position = 0,
  });

  final String id;
  final String name;
  final int position;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: asString(json['id']),
        name: asString(json['name'], 'Category'),
        position: asIntOrNull(json['position']) ?? 0,
      );
}

class ChannelBundle {
  const ChannelBundle({
    this.categories = const [],
    this.channels = const [],
    this.permissions = const {},
  });

  final List<Category> categories;
  final List<Channel> channels;
  final Map<String, String> permissions;

  factory ChannelBundle.fromJson(Map<String, dynamic> json) => ChannelBundle(
        categories: asList(json['categories'])
            .whereType<Map>()
            .map((value) => Category.fromJson(asMap(value)))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
        channels: asList(json['channels'])
            .whereType<Map>()
            .map((value) => Channel.fromJson(asMap(value)))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
        permissions: asMap(json['permissions'])
            .map((key, value) => MapEntry(key, '$value')),
      );
}

class AnalyticsPoint {
  const AnalyticsPoint({
    required this.at,
    required this.memberCount,
    required this.presenceCount,
    required this.voicePeak,
  });

  final DateTime? at;
  final int memberCount;
  final int presenceCount;
  final int voicePeak;

  factory AnalyticsPoint.fromJson(Map<String, dynamic> json) => AnalyticsPoint(
        at: asDate(json['at']),
        memberCount: asInt(json['member_count']),
        presenceCount: asInt(json['presence_count']),
        voicePeak: asInt(json['voice_peak']),
      );
}

class AnalyticsScope {
  const AnalyticsScope({this.bucketSeconds = 0, this.series = const []});

  final int bucketSeconds;
  final List<AnalyticsPoint> series;

  factory AnalyticsScope.fromJson(Map<String, dynamic> json) => AnalyticsScope(
        bucketSeconds: asInt(json['bucket_seconds']),
        series: asList(json['series'])
            .whereType<Map>()
            .map((value) => AnalyticsPoint.fromJson(asMap(value)))
            .toList(),
      );
}

class AnalyticsBundle {
  const AnalyticsBundle({
    this.memberCount = 0,
    this.presenceCount = 0,
    this.voiceCount = 0,
    this.scopes = const {},
    this.activeUsers,
  });

  final int memberCount;
  final int presenceCount;
  final int voiceCount;
  final Map<String, AnalyticsScope> scopes;
  final Map<String, dynamic>? activeUsers;

  factory AnalyticsBundle.fromJson(Map<String, dynamic> json) {
    final live = asMap(json['live']);
    return AnalyticsBundle(
      memberCount: asInt(live['member_count']),
      presenceCount: asInt(live['presence_count']),
      voiceCount: asInt(live['voice_count']),
      scopes: asMap(json['scopes']).map(
        (key, value) => MapEntry(key, AnalyticsScope.fromJson(asMap(value))),
      ),
      activeUsers:
          json['active_users'] is Map ? asMap(json['active_users']) : null,
    );
  }
}

class ConversationMember {
  const ConversationMember({required this.user, this.role});

  final User user;
  final String? role;

  factory ConversationMember.fromJson(Map<String, dynamic> json) =>
      ConversationMember(
        user: User.fromJson(asMap(json['user'] ?? json)),
        role: asStringOrNull(json['role']),
      );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    this.name,
    this.iconUrl,
    this.isMuted = false,
    this.lastMessageAt,
    this.lastMessage,
    this.members = const [],
    this.unreadCount = 0,
  });

  final String id;
  final String type;
  final String? name;
  final String? iconUrl;
  final bool isMuted;
  final DateTime? lastMessageAt;
  final Message? lastMessage;
  final List<ConversationMember> members;
  final int unreadCount;

  bool get isGroup =>
      type.toLowerCase().contains('group') || members.length > 2;

  String titleFor(String myId) {
    if (name?.trim().isNotEmpty == true) return name!.trim();
    final people = members.where((member) => member.user.id != myId);
    return people.isEmpty
        ? 'Direct message'
        : people.map((member) => member.user.name).join(', ');
  }

  User? otherUser(String myId) {
    for (final member in members) {
      if (member.user.id != myId) return member.user;
    }
    return members.isEmpty ? null : members.first.user;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawLast = json['last_message'];
    return Conversation(
      id: asString(json['id']),
      type: asString(json['type'], 'direct'),
      name: asStringOrNull(json['name']),
      iconUrl: asStringOrNull(json['icon_url']),
      isMuted: asBool(json['is_muted']),
      lastMessageAt: asDate(json['last_message_at']),
      lastMessage: rawLast is Map ? Message.fromJson(asMap(rawLast)) : null,
      members: asList(json['members'])
          .whereType<Map>()
          .map((value) => ConversationMember.fromJson(asMap(value)))
          .toList(),
      unreadCount: asIntOrNull(json['unread_count']) ?? 0,
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.status,
    this.createdAt,
    this.sender,
    this.receiver,
  });

  final String id;
  final String status;
  final DateTime? createdAt;
  final User? sender;
  final User? receiver;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: asString(json['id']),
        status: asString(json['status'], 'pending'),
        createdAt: asDate(json['created_at']),
        sender:
            json['sender'] is Map ? User.fromJson(asMap(json['sender'])) : null,
        receiver: json['receiver'] is Map
            ? User.fromJson(asMap(json['receiver']))
            : null,
      );
}

class FriendRequests {
  const FriendRequests({this.incoming = const [], this.outgoing = const []});

  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;

  factory FriendRequests.fromJson(Map<String, dynamic> json) => FriendRequests(
        incoming: asList(json['incoming'])
            .whereType<Map>()
            .map((value) => FriendRequest.fromJson(asMap(value)))
            .toList(),
        outgoing: asList(json['outgoing'])
            .whereType<Map>()
            .map((value) => FriendRequest.fromJson(asMap(value)))
            .toList(),
      );
}

class Member {
  const Member({
    required this.user,
    this.userId,
    this.nickname,
    this.roleIds = const [],
    this.presence,
    this.isOwner = false,
    this.joinedAt,
  });

  final User user;
  final String? userId;
  final String? nickname;
  final List<String> roleIds;
  final String? presence;
  final bool isOwner;
  final DateTime? joinedAt;

  String get id => userId ?? user.id;
  String get displayName =>
      nickname?.trim().isNotEmpty == true ? nickname!.trim() : user.name;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        user: User.fromJson(asMap(json['user'])),
        userId: asStringOrNull(json['user_id']),
        nickname: asStringOrNull(json['nickname']),
        roleIds: asList(json['role_ids'] ?? json['roles'])
            .map((value) => '$value')
            .toList(),
        presence: asStringOrNull(json['presence']),
        isOwner: asBool(json['is_owner']),
        joinedAt: asDate(json['joined_at']),
      );
}

class MemberListSection {
  const MemberListSection({
    required this.key,
    required this.label,
    required this.count,
    this.roleId,
    this.memberIds = const [],
  });

  final String key;
  final String label;
  final String? roleId;
  final int count;
  final List<String> memberIds;

  factory MemberListSection.fromJson(Map<String, dynamic> json) =>
      MemberListSection(
        key: asString(json['key']),
        label: asString(json['label']),
        roleId: asStringOrNull(json['role_id']),
        count: asInt(json['count']),
        memberIds: asList(json['member_ids']).map((value) => '$value').toList(),
      );
}

class MemberListSnapshot {
  const MemberListSnapshot({
    this.members = const [],
    this.total = 0,
    this.sections = const [],
    this.roles = const [],
  });

  final List<Member> members;
  final int total;
  final List<MemberListSection> sections;
  final List<Role> roles;

  factory MemberListSnapshot.fromJson(Map<String, dynamic> json) =>
      MemberListSnapshot(
        members: asList(json['members'])
            .whereType<Map>()
            .map((value) => Member.fromJson(asMap(value)))
            .toList(),
        total: asInt(json['total']),
        sections: asList(json['sections'])
            .whereType<Map>()
            .map((value) => MemberListSection.fromJson(asMap(value)))
            .toList(),
        roles: asList(json['roles'])
            .whereType<Map>()
            .map((value) => Role.fromJson(asMap(value)))
            .toList(),
      );
}

class Role {
  const Role({
    required this.id,
    required this.name,
    this.permissions = '0',
    this.position = 0,
    this.color,
    this.hoist = false,
    this.mentionable = false,
    this.isEveryone = false,
    this.iconUrl,
    this.iconEmoji,
    this.memberCount,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String permissions;
  final int position;
  final String? color;
  final bool hoist;
  final bool mentionable;
  final bool isEveryone;
  final String? iconUrl;
  final String? iconEmoji;
  final int? memberCount;
  final String? updatedAt;

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: asString(json['id']),
        name: asString(json['name'], 'Role'),
        permissions: '${json['permissions'] ?? '0'}',
        position: asIntOrNull(json['position']) ?? 0,
        color: asColor(json['color']),
        hoist: asBool(json['hoist']),
        mentionable: asBool(json['mentionable']),
        isEveryone: asBool(json['is_everyone']),
        iconUrl: asStringOrNull(json['icon_url']),
        iconEmoji: asStringOrNull(json['icon_emoji']),
        memberCount: asIntOrNull(json['member_count']),
        updatedAt: asStringOrNull(json['updated_at']),
      );
}

class RolesResponse {
  const RolesResponse({this.roles = const [], this.canViewPermissions = false});

  final List<Role> roles;
  final bool canViewPermissions;

  factory RolesResponse.fromJson(Map<String, dynamic> json) => RolesResponse(
        roles: asList(json['roles'])
            .whereType<Map>()
            .map((value) => Role.fromJson(asMap(value)))
            .toList(),
        canViewPermissions: asBool(json['can_view_role_permissions']),
      );
}

class Invite {
  const Invite({
    required this.code,
    this.url,
    this.serverId,
    this.channelId,
    this.maxUses,
    this.uses = 0,
    this.expiresAt,
    this.createdAt,
    this.creatorUsername,
    this.creatorName,
    this.creatorAvatarUrl,
  });

  final String code;
  final String? url;
  final String? serverId;
  final String? channelId;
  final int? maxUses;
  final int uses;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? creatorUsername;
  final String? creatorName;
  final String? creatorAvatarUrl;

  String get displayUrl => url ?? 'https://flackle.com/invite/$code';

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
        code: asString(json['code']),
        url: asStringOrNull(json['url']),
        serverId: asStringOrNull(json['server_id']),
        channelId: asStringOrNull(json['channel_id']),
        maxUses: asIntOrNull(json['max_uses']),
        uses: asInt(json['uses']),
        expiresAt: asDate(json['expires_at']),
        createdAt: asDate(json['created_at']),
        creatorUsername: asStringOrNull(json['creator_username']),
        creatorName: asStringOrNull(json['creator_name']),
        creatorAvatarUrl: asStringOrNull(json['creator_avatar_url']),
      );
}

class ServerBan {
  const ServerBan({
    required this.userId,
    this.user,
    this.reason,
    this.moderatorId,
    this.createdAt,
  });

  final String userId;
  final User? user;
  final String? reason;
  final String? moderatorId;
  final DateTime? createdAt;

  factory ServerBan.fromJson(Map<String, dynamic> json) => ServerBan(
        userId: asString(json['user_id']),
        user: json['user'] is Map ? User.fromJson(asMap(json['user'])) : null,
        reason: asStringOrNull(json['reason']),
        moderatorId: asStringOrNull(json['moderator_id']),
        createdAt: asDate(json['created_at']),
      );
}

class AuditChange {
  const AuditChange({this.key, this.oldValue, this.newValue});

  final String? key;
  final dynamic oldValue;
  final dynamic newValue;

  factory AuditChange.fromJson(Map<String, dynamic> json) => AuditChange(
        key: asStringOrNull(json['key']),
        oldValue: json['old'],
        newValue: json['new'],
      );
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actionType,
    this.actor,
    this.targetId,
    this.targetKind,
    this.targetUser,
    this.changes = const [],
    this.options = const {},
    this.createdAt,
  });

  final String id;
  final String actionType;
  final User? actor;
  final String? targetId;
  final String? targetKind;
  final User? targetUser;
  final List<AuditChange> changes;
  final Map<String, dynamic> options;
  final DateTime? createdAt;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: asString(json['id']),
        actionType: asString(json['action_type'], 'update'),
        actor:
            json['actor'] is Map ? User.fromJson(asMap(json['actor'])) : null,
        targetId: asStringOrNull(json['target_id']),
        targetKind: asStringOrNull(json['target_kind']),
        targetUser: json['target_user'] is Map
            ? User.fromJson(asMap(json['target_user']))
            : null,
        changes: asList(json['changes'])
            .whereType<Map>()
            .map((value) => AuditChange.fromJson(asMap(value)))
            .toList(),
        options: asMap(json['options']),
        createdAt: asDate(json['created_at']),
      );
}

class LiftsInfo {
  const LiftsInfo({
    this.level = 0,
    this.count = 0,
    this.nextLevelAt = 0,
    this.maxUploadBytes = 0,
    this.savedBudgetBytes = 0,
    this.retentionMultiplier = 1,
    this.levels = const [],
    this.supporters = const [],
  });

  final int level;
  final int count;
  final int nextLevelAt;
  final int maxUploadBytes;
  final int savedBudgetBytes;
  final double retentionMultiplier;
  final List<Map<String, dynamic>> levels;
  final List<User> supporters;

  factory LiftsInfo.fromJson(Map<String, dynamic> json) => LiftsInfo(
        level: asInt(json['level']),
        count: asInt(json['count']),
        nextLevelAt: asInt(json['next_level_at']),
        maxUploadBytes: asInt(json['max_upload_bytes']),
        savedBudgetBytes: asInt(json['saved_budget_bytes']),
        retentionMultiplier:
            (json['retention_multiplier'] as num?)?.toDouble() ?? 1,
        levels: asList(json['levels']).whereType<Map>().map(asMap).toList(),
      );
}

class SavedMediaItem {
  const SavedMediaItem({
    required this.url,
    this.fileName,
    this.fileSize,
    this.contentType,
    this.expiresAt,
    this.savedAt,
  });

  final String url;
  final String? fileName;
  final int? fileSize;
  final String? contentType;
  final DateTime? expiresAt;
  final DateTime? savedAt;

  bool get isImage => (contentType ?? '').startsWith('image/');

  factory SavedMediaItem.fromJson(Map<String, dynamic> json) => SavedMediaItem(
        url: asString(json['url']),
        fileName: asStringOrNull(json['file_name']),
        fileSize: asIntOrNull(json['file_size']),
        contentType: asStringOrNull(json['content_type']),
        expiresAt: asDate(json['expires_at']),
        savedAt: asDate(json['saved_at']),
      );
}

class SavedMediaPage {
  const SavedMediaPage({
    this.items = const [],
    this.count = 0,
    this.used = 0,
    this.budget = 0,
    this.nextCursor,
  });

  final List<SavedMediaItem> items;
  final int count;
  final int used;
  final int budget;
  final String? nextCursor;

  factory SavedMediaPage.fromJson(Map<String, dynamic> json) => SavedMediaPage(
        items: asList(json['items'])
            .whereType<Map>()
            .map((value) => SavedMediaItem.fromJson(asMap(value)))
            .toList(),
        count: asInt(json['count']),
        used: asInt(json['used']),
        budget: asInt(json['budget']),
        nextCursor: asStringOrNull(json['next_cursor']),
      );
}

class ProfileBlock {
  const ProfileBlock({
    this.id,
    required this.type,
    this.content,
    this.level,
    this.order,
    this.platform,
    this.username,
    this.url,
    this.imageUrl,
  });

  final String? id;
  final String type;
  final String? content;
  final int? level;
  final int? order;
  final String? platform;
  final String? username;
  final String? url;
  final String? imageUrl;

  factory ProfileBlock.fromJson(Map<String, dynamic> json) => ProfileBlock(
        id: asStringOrNull(json['id']),
        type: asString(json['type'], 'text'),
        content: asStringOrNull(json['content']),
        level: asIntOrNull(json['level']),
        order: asIntOrNull(json['order']),
        platform: asStringOrNull(json['platform']),
        username: asStringOrNull(json['username']),
        url: asStringOrNull(json['url']),
        imageUrl: asStringOrNull(json['image_url']),
      );
}

class ProfileBadge {
  const ProfileBadge({
    required this.key,
    required this.name,
    this.description,
    this.iconUrl,
  });

  final String key;
  final String name;
  final String? description;
  final String? iconUrl;

  factory ProfileBadge.fromJson(Map<String, dynamic> json) {
    final key = asString(json['key'] ?? json['id'] ?? json['type']);
    return ProfileBadge(
      key: key,
      name: asString(json['name'] ?? json['label'], key),
      description: asStringOrNull(json['description']),
      iconUrl: asStringOrNull(json['icon_url'] ?? json['icon']),
    );
  }

  static ProfileBadge? fromValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return ProfileBadge(key: value.trim(), name: value.trim());
    }
    if (value is Map) return ProfileBadge.fromJson(asMap(value));
    return null;
  }

  String get resolvedIconUrl {
    final url = iconUrl;
    if (url != null && url.isNotEmpty) return url;
    return 'https://flackle.com/badges/$key-96.png';
  }
}

class UserCard {
  const UserCard({
    required this.user,
    this.member,
    this.membership,
    this.badges = const [],
    this.blocks = const [],
    this.socials = const [],
    this.mutualFriendIds = const [],
    this.mutualServerIds = const [],
  });

  final User user;
  final Member? member;
  final String? membership;
  final List<ProfileBadge> badges;
  final List<ProfileBlock> blocks;
  final List<ProfileBlock> socials;
  final List<String> mutualFriendIds;
  final List<String> mutualServerIds;

  factory UserCard.fromJson(Map<String, dynamic> json) => UserCard(
        user: User.fromJson(asMap(json['user'])),
        member: json['member'] is Map
            ? Member.fromJson(asMap(json['member']))
            : null,
        membership: asStringOrNull(json['membership']),
        badges: asList(json['badges'])
            .map(ProfileBadge.fromValue)
            .whereType<ProfileBadge>()
            .toList(),
        blocks: asList(json['blocks'])
            .whereType<Map>()
            .map((value) => ProfileBlock.fromJson(asMap(value)))
            .toList(),
        socials: asList(json['socials'])
            .whereType<Map>()
            .map((value) => ProfileBlock.fromJson(asMap(value)))
            .toList(),
        mutualFriendIds:
            asList(json['mutual_friend_ids']).map((value) => '$value').toList(),
        mutualServerIds:
            asList(json['mutual_server_ids']).map((value) => '$value').toList(),
      );
}

class BentoCard {
  const BentoCard({
    this.id,
    required this.type,
    this.width = 3,
    this.height = 1,
    this.data = const {},
  });

  final String? id;
  final String type;
  final int width;
  final int height;
  final Map<String, dynamic> data;

  factory BentoCard.fromJson(Map<String, dynamic> json) => BentoCard(
        id: asStringOrNull(json['id']),
        type: asString(json['type'], 'text'),
        width: asIntOrNull(json['width']) ?? 3,
        height: asIntOrNull(json['height']) ?? 1,
        data: asMap(json['data']),
      );
}

class UnreadChannel {
  const UnreadChannel({
    required this.serverId,
    required this.channelId,
    this.unreadCount = 0,
    this.mentionCount = 0,
  });

  final String serverId;
  final String channelId;
  final int unreadCount;
  final int mentionCount;

  factory UnreadChannel.fromJson(Map<String, dynamic> json) => UnreadChannel(
        serverId: asString(json['server_id']),
        channelId: asString(json['channel_id']),
        unreadCount: asInt(json['unread_count']),
        mentionCount: asInt(json['mention_count']),
      );
}

class UnreadSummary {
  const UnreadSummary({this.channels = const []});

  final List<UnreadChannel> channels;

  factory UnreadSummary.fromJson(Map<String, dynamic> json) => UnreadSummary(
        channels: asList(json['channels'])
            .whereType<Map>()
            .map((value) => UnreadChannel.fromJson(asMap(value)))
            .toList(),
      );
}

class AuthSession {
  const AuthSession({
    required this.id,
    this.ipAddress,
    this.userAgent,
    this.location,
    this.createdAt,
    this.lastUsedAt,
    this.current = false,
  });

  final String id;
  final String? ipAddress;
  final String? userAgent;
  final String? location;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool current;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        id: asString(json['id']),
        ipAddress: asStringOrNull(json['ip_address']),
        userAgent: asStringOrNull(json['user_agent']),
        location: asStringOrNull(json['location']),
        createdAt: asDate(json['created_at']),
        lastUsedAt: asDate(json['last_used_at']),
        current: asBool(json['current']),
      );
}

class SecurityEvent {
  const SecurityEvent({
    required this.eventType,
    this.userAgent,
    this.createdAt,
    this.unusual = false,
    this.unusualReason,
    this.originLocation,
  });

  final String eventType;
  final String? userAgent;
  final DateTime? createdAt;
  final bool unusual;
  final String? unusualReason;
  final String? originLocation;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
        eventType: asString(json['event_type']),
        userAgent: asStringOrNull(json['user_agent']),
        createdAt: asDate(json['created_at']),
        unusual: asBool(json['unusual']),
        unusualReason: asStringOrNull(json['unusual_reason']),
        originLocation: asStringOrNull(json['origin_location']),
      );
}

class TwoFactorStatus {
  const TwoFactorStatus({
    this.enabled = false,
    this.pending = false,
    this.backupCodesRemaining = 0,
  });

  final bool enabled;
  final bool pending;
  final int backupCodesRemaining;

  factory TwoFactorStatus.fromJson(Map<String, dynamic> json) =>
      TwoFactorStatus(
        enabled: asBool(json['enabled']),
        pending: asBool(json['pending']),
        backupCodesRemaining: asInt(json['backup_codes_remaining']),
      );
}

class TwoFactorSetup {
  const TwoFactorSetup({required this.secret, this.otpauthUrl, this.qrCode});

  final String secret;
  final String? otpauthUrl;
  final String? qrCode;

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) => TwoFactorSetup(
        secret: asString(json['secret']),
        otpauthUrl: asStringOrNull(json['otpauth_url']),
        qrCode: asStringOrNull(json['qr_code']),
      );
}

class GifFolder {
  const GifFolder({
    required this.id,
    required this.name,
    this.iconUrl,
    this.position,
  });

  final String id;
  final String name;
  final String? iconUrl;
  final int? position;

  factory GifFolder.fromJson(Map<String, dynamic> json) => GifFolder(
        id: asString(json['id']),
        name: asString(json['name'], 'GIF folder'),
        iconUrl: asStringOrNull(json['icon_url']),
        position: asIntOrNull(json['position']),
      );
}

class GifResult {
  const GifResult({
    required this.id,
    required this.title,
    required this.gifUrl,
    required this.previewUrl,
    this.videoUrl,
    this.width = 200,
    this.height = 200,
    this.folderId,
    this.savedAt,
  });

  final String id;
  final String title;
  final String gifUrl;
  final String previewUrl;
  final String? videoUrl;
  final int width;
  final int height;
  final String? folderId;
  final DateTime? savedAt;

  factory GifResult.fromKlipy(Map<String, dynamic> json) {
    final files = asMap(json['file']);
    final small = asMap(files['sm']);
    final gif = asMap(small['gif']);
    final webp = asMap(small['webp']);
    final gifUrl = asStringOrNull(gif['url']) ?? '';
    return GifResult(
      id: asString(json['id']),
      title: asString(json['title'], 'GIF'),
      gifUrl: gifUrl,
      previewUrl: asStringOrNull(webp['url']) ?? gifUrl,
      videoUrl: asStringOrNull(webp['url']) ?? gifUrl,
      width: asIntOrNull(webp['width']) ?? asIntOrNull(gif['width']) ?? 200,
      height: asIntOrNull(webp['height']) ?? asIntOrNull(gif['height']) ?? 200,
    );
  }

  factory GifResult.fromSaved(Map<String, dynamic> json) {
    final url = asStringOrNull(json['url']) ?? '';
    return GifResult(
      id: asStringOrNull(json['id']) ?? url,
      title: asString(json['title'], 'GIF'),
      gifUrl: url,
      previewUrl: asStringOrNull(json['preview_url']) ?? url,
      videoUrl: asStringOrNull(json['video_url']),
      width: asIntOrNull(json['width']) ?? 200,
      height: asIntOrNull(json['height']) ?? 200,
      folderId: asStringOrNull(json['folder_id']),
      savedAt: asDate(json['saved_at']),
    );
  }

  GifResult copyWith({
    String? folderId,
    DateTime? savedAt,
    bool clearFolder = false,
  }) =>
      GifResult(
        id: id,
        title: title,
        gifUrl: gifUrl,
        previewUrl: previewUrl,
        videoUrl: videoUrl,
        width: width,
        height: height,
        folderId: clearFolder ? null : folderId ?? this.folderId,
        savedAt: savedAt ?? this.savedAt,
      );

  Map<String, dynamic> toSaveJson(String? folderId) => {
        'url': gifUrl,
        'preview_url': previewUrl,
        if (videoUrl != null) 'video_url': videoUrl,
        'width': width,
        'height': height,
        'folder_id': folderId,
      };
}

class GifLibrary {
  const GifLibrary({this.folders = const [], this.saved = const []});

  final List<GifFolder> folders;
  final List<GifResult> saved;

  factory GifLibrary.fromJson(Map<String, dynamic> json) => GifLibrary(
        folders: asList(json['folders'])
            .whereType<Map>()
            .map((value) => GifFolder.fromJson(asMap(value)))
            .toList(),
        saved: asList(json['saved'])
            .whereType<Map>()
            .map((value) => GifResult.fromSaved(asMap(value)))
            .where((gif) => gif.gifUrl.isNotEmpty)
            .toList(),
      );
}

class MessagePage {
  const MessagePage({
    this.messages = const [],
    this.hasMore = false,
    this.hasMoreBefore = false,
    this.hasMoreAfter = false,
  });

  final List<Message> messages;
  final bool hasMore;
  final bool hasMoreBefore;
  final bool hasMoreAfter;

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
        messages: asList(json['messages'])
            .whereType<Map>()
            .map((value) => Message.fromJson(asMap(value)))
            .toList(),
        hasMore: asBool(json['has_more']),
        hasMoreBefore: asBool(json['has_more_before']),
        hasMoreAfter: asBool(json['has_more_after']),
      );
}

class ServerUserSettings {
  const ServerUserSettings({
    required this.serverId,
    this.position,
    this.folderId,
    this.notificationLevel,
    this.lastViewedChannelId,
    this.collapsedCategories = const [],
  });

  final String serverId;
  final int? position;
  final String? folderId;
  final String? notificationLevel;
  final String? lastViewedChannelId;
  final List<String> collapsedCategories;

  factory ServerUserSettings.fromJson(Map<String, dynamic> json) =>
      ServerUserSettings(
        serverId: asString(json['server_id']),
        position: asIntOrNull(json['position']),
        folderId: asStringOrNull(json['folder_id']),
        notificationLevel: asStringOrNull(json['notification_level']),
        lastViewedChannelId: asStringOrNull(json['last_viewed_channel_id']),
        collapsedCategories: asList(json['collapsed_categories'])
            .map((value) => '$value')
            .toList(),
      );

  ServerUserSettings copyWith({
    int? position,
    String? folderId,
    bool clearFolder = false,
    String? notificationLevel,
    String? lastViewedChannelId,
    List<String>? collapsedCategories,
  }) =>
      ServerUserSettings(
        serverId: serverId,
        position: position ?? this.position,
        folderId: clearFolder ? null : folderId ?? this.folderId,
        notificationLevel: notificationLevel ?? this.notificationLevel,
        lastViewedChannelId: lastViewedChannelId ?? this.lastViewedChannelId,
        collapsedCategories: collapsedCategories ?? this.collapsedCategories,
      );
}

class ServerFolder {
  const ServerFolder({
    required this.id,
    required this.name,
    this.color,
    this.position = 0,
    this.railPosition,
  });

  final String id;
  final String name;
  final String? color;
  final int position;
  final int? railPosition;

  int get effectivePosition => railPosition ?? position;

  factory ServerFolder.fromJson(Map<String, dynamic> json) => ServerFolder(
        id: asString(json['id']),
        name: asString(json['name'], 'Folder'),
        color: asColor(json['color']),
        position: asIntOrNull(json['position']) ?? 0,
        railPosition: asIntOrNull(json['rail_position']),
      );

  ServerFolder copyWith({
    String? name,
    String? color,
    int? position,
    int? railPosition,
    bool clearColor = false,
  }) =>
      ServerFolder(
        id: id,
        name: name ?? this.name,
        color: clearColor ? null : color ?? this.color,
        position: position ?? this.position,
        railPosition: railPosition ?? this.railPosition,
      );
}

class ServerPreferences {
  const ServerPreferences({
    this.folders = const [],
    this.settings = const [],
  });

  final List<ServerFolder> folders;
  final List<ServerUserSettings> settings;

  factory ServerPreferences.fromJson(Map<String, dynamic> json) =>
      ServerPreferences(
        folders: asList(json['folders'])
            .whereType<Map>()
            .map((value) => ServerFolder.fromJson(asMap(value)))
            .toList(),
        settings: asList(json['server_settings'])
            .whereType<Map>()
            .map((value) => ServerUserSettings.fromJson(asMap(value)))
            .toList(),
      );
}

/// Identifies whatever the chat pane is showing.
class Target {
  const Target.channel(this.serverId, this.channelId)
      : conversationId = null,
        serverName = null,
        title = null,
        topic = null,
        icon = null,
        iconColor = null,
        channelType = null;

  const Target.conversation(this.conversationId, {required this.title})
      : serverId = null,
        channelId = null,
        serverName = null,
        topic = null,
        icon = null,
        iconColor = null,
        channelType = null;

  const Target.channelView({
    required this.serverId,
    required this.serverName,
    required this.channelId,
    required this.title,
    required this.channelType,
    this.topic,
    this.icon,
    this.iconColor,
  }) : conversationId = null;

  final String? serverId;
  final String? channelId;
  final String? conversationId;
  final String? serverName;
  final String? title;
  final String? topic;
  final String? channelType;
  final String? icon;
  final String? iconColor;

  bool get isChannel => serverId != null && channelId != null;

  String get key => isChannel ? 'g:$serverId:$channelId' : 'd:$conversationId';

  String get messagesPath => isChannel
      ? '/api/servers/$serverId/channels/$channelId/messages'
      : '/api/conversations/$conversationId/messages';

  String get attachmentsPath => isChannel
      ? '/api/servers/$serverId/channels/$channelId/attachments'
      : '/api/conversations/$conversationId/attachments';

  Map<String, dynamic> toJson() => isChannel
      ? {'server_id': serverId, 'channel_id': channelId}
      : {'conversation_id': conversationId};
}
