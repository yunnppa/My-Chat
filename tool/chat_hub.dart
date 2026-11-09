import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// In-memory chat directory shared by every connected client.
class ChatHub {
  ChatHub({Random? random, DateTime Function()? now})
    : _random = random ?? Random(),
      _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;
  final Map<String, HubUser> _usersById = {};
  final Map<String, String> _userIdByToken = {};
  final Map<String, HubChat> _chats = {};
  final Map<String, List<HubMessage>> _messages = {};
  final Map<String, Set<HubListener>> _listeners = {};
  final List<HubStory> _stories = [];

  HubUser register({String? token, required String displayName}) {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw HubException('Display name is required');
    }

    if (token != null && _userIdByToken.containsKey(token)) {
      final user = _usersById[_userIdByToken[token]!]!;
      _ensureNameAvailable(name, exceptUserId: user.id);
      user.displayName = name;
      return user;
    }

    _ensureNameAvailable(name);
    final user = HubUser(
      id: _id('user'),
      displayName: name,
      token: _id('token'),
    );
    _usersById[user.id] = user;
    _userIdByToken[user.token] = user.id;
    return user;
  }

  void _ensureNameAvailable(String name, {String? exceptUserId}) {
    final needle = name.toLowerCase();
    final taken = _usersById.values.any(
      (user) =>
          user.id != exceptUserId && user.displayName.toLowerCase() == needle,
    );
    if (taken) {
      throw HubException('this username is taken', status: 409);
    }
  }

  List<HubUser> searchUsers({required String token, String query = ''}) {
    final me = _requireUser(token);
    final needle = query.trim().toLowerCase();
    return _usersById.values
        .where((user) => user.id != me.id)
        .where(
          (user) =>
              needle.isEmpty || user.displayName.toLowerCase().contains(needle),
        )
        .toList();
  }

  List<HubChatView> chatsFor(String token) {
    final me = _requireUser(token);
    final views = _chats.values
        .where((chat) => chat.participantIds.contains(me.id))
        .where((chat) => chat.isVisibleTo(me.id))
        .map((chat) => _view(chat, me.id))
        .toList();
    views.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return views;
  }

  HubChatView openDirect({required String token, required String otherUserId}) {
    final me = _requireUser(token);
    if (otherUserId == me.id) {
      throw HubException('Choose someone else to message');
    }
    if (!_usersById.containsKey(otherUserId)) {
      throw HubException('That person is not on the server', status: 404);
    }
    final ids = [me.id, otherUserId]..sort();
    final id = ids.join('_');
    final chat = _chats.putIfAbsent(
      id,
      () => HubChat(id: id, participantIds: ids),
    );
    chat.hiddenForUserIds.remove(me.id);
    _messages.putIfAbsent(id, () => []);
    final view = _view(chat, me.id);
    _emit(chat.participantIds, {'type': 'chat', 'chatId': chat.id});
    return view;
  }

  void deleteChat({
    required String token,
    required String chatId,
    required String scope,
  }) {
    final me = _requireUser(token);
    final chat = _requireChat(chatId, me.id, allowHidden: true);
    if (scope == 'both') {
      final recipients = List<String>.from(chat.participantIds);
      _chats.remove(chat.id);
      _messages.remove(chat.id);
      _emit(recipients, {'type': 'chat', 'chatId': chat.id, 'deleted': true});
      return;
    }
    if (scope != 'me') {
      throw HubException('Choose delete for you or delete for both');
    }
    chat.hiddenForUserIds.add(me.id);
    _emit([me.id], {'type': 'chat', 'chatId': chat.id, 'deleted': true});
  }

  void setPublicKey({required String token, required String publicKey}) {
    final key = publicKey.trim();
    if (key.isEmpty) throw HubException('Public key required');
    _requireUser(token).publicKey = key;
  }

  String? publicKeyOf(String userId) => _usersById[userId]?.publicKey;

  void registerPushToken({required String token, required String fcmToken}) {
    final device = fcmToken.trim();
    if (device.isEmpty) throw HubException('Push token required');
    _requireUser(token).fcmTokens.add(device);
  }

  Set<String> pushTokensFor(String userId) {
    final user = _usersById[userId];
    if (user == null) return const {};
    return Set<String>.from(user.fcmTokens);
  }

  /// Recipients (excluding the sender) and display text for a push alert.
  HubPushNotice? pushNoticeForMessage({
    required String senderId,
    required HubMessage message,
  }) {
    final chat = _chats[message.chatId];
    final sender = _usersById[senderId];
    if (chat == null || sender == null) return null;
    final tokens = <String>{};
    for (final participantId in chat.participantIds) {
      if (participantId == senderId) continue;
      tokens.addAll(pushTokensFor(participantId));
    }
    if (tokens.isEmpty) return null;
    final body = message.text.startsWith('e2e1.')
        ? 'Encrypted message'
        : message.text;
    return HubPushNotice(
      tokens: tokens,
      title: sender.displayName,
      body: body,
      chatId: message.chatId,
      messageId: message.id,
      senderId: senderId,
    );
  }

  HubChatView markRead({required String token, required String chatId}) {
    final me = _requireUser(token);
    final chat = _requireChat(chatId, me.id);
    var readAt = DateTime.now().toUtc();
    for (final message in _messages[chat.id] ?? const <HubMessage>[]) {
      if (message.createdAt.isAfter(readAt)) readAt = message.createdAt;
    }
    chat.lastReadAt[me.id] = readAt;
    final view = _view(chat, me.id);
    _emit([me.id], {'type': 'chat', 'chatId': chat.id});
    return view;
  }

  List<HubMessage> messages({required String token, required String chatId}) {
    final me = _requireUser(token);
    final chat = _requireChat(chatId, me.id);
    return List.unmodifiable(_messages[chat.id] ?? const []);
  }

  HubMessage send({
    required String token,
    required String chatId,
    required String text,
  }) {
    final me = _requireUser(token);
    final chat = _requireChat(chatId, me.id);
    final body = text.trim();
    if (body.isEmpty) {
      throw HubException('Message is empty');
    }
    final message = HubMessage(
      id: _id('msg'),
      chatId: chat.id,
      senderId: me.id,
      text: body,
      createdAt: DateTime.now().toUtc(),
    );
    _messages.putIfAbsent(chat.id, () => []).add(message);
    chat.lastMessagePreview = body.startsWith('e2e1.')
        ? 'Encrypted message'
        : body;
    chat.lastMessageAt = message.createdAt;
    for (final participantId in chat.participantIds) {
      if (participantId != me.id) {
        chat.hiddenForUserIds.remove(participantId);
      }
    }
    _emit(chat.participantIds, {
      'type': 'message',
      'chatId': chat.id,
      'senderName': me.displayName,
      'message': message.toJson(),
    });
    return message;
  }

  int setAvatar({required String token, required List<int> bytes}) {
    if (bytes.isEmpty) {
      throw HubException('Choose a photo');
    }
    if (bytes.length > 1500000) {
      throw HubException('That photo is too large');
    }
    final user = _requireUser(token);
    user.avatar = Uint8List.fromList(bytes);
    user.avatarRevision += 1;
    final recipients = <String>{user.id};
    for (final chat in _chats.values) {
      if (chat.participantIds.contains(user.id)) {
        recipients.addAll(chat.participantIds);
      }
    }
    _emit(recipients.toList(), {'type': 'avatar', 'userId': user.id});
    return user.avatarRevision;
  }

  Uint8List? avatarOf(String userId) => _usersById[userId]?.avatar;

  HubStoryView addStory({
    required String token,
    required List<int> bytes,
    String? visibility,
  }) {
    if (bytes.isEmpty) {
      throw HubException('Choose a photo');
    }
    if (bytes.length > 2500000) {
      throw HubException('That photo is too large');
    }
    if (visibility != null &&
        visibility != 'public' &&
        visibility != 'friends' &&
        visibility != 'onlyMe') {
      throw HubException('Choose public, friends only, or only me');
    }
    final user = _requireUser(token);
    if (visibility != null) user.storyVisibility = visibility;
    _pruneStories();
    final story = HubStory(
      id: _id('story'),
      userId: user.id,
      createdAt: _now().toUtc(),
      image: Uint8List.fromList(bytes),
      visibility: visibility,
    );
    _stories.add(story);
    _emit(_usersById.keys.toList(), {'type': 'story', 'storyId': story.id});
    return _storyView(story, user);
  }

  List<HubStoryView> storiesFor(String token) {
    final viewer = _requireUser(token);
    _pruneStories();
    final views = [
      for (final story in _stories)
        if (_canViewStory(viewer, story)) _storyView(story, viewer),
    ];
    views.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return views;
  }

  Uint8List? storyImage({required String token, required String storyId}) {
    final viewer = _requireUser(token);
    final story = _visibleStory(viewer, storyId);
    if (story == null) return null;
    _rememberViewer(story, viewer);
    return story.image;
  }

  void recordStoryView({required String token, required String storyId}) {
    final viewer = _requireUser(token);
    final story = _visibleStory(viewer, storyId);
    if (story == null) {
      throw HubException('No story', status: 404);
    }
    _rememberViewer(story, viewer);
  }

  List<HubUser> storyViewers({required String token, required String storyId}) {
    final viewer = _requireUser(token);
    final story = _visibleStory(viewer, storyId);
    if (story == null) {
      throw HubException('No story', status: 404);
    }
    if (viewer.id != story.userId) {
      throw HubException('Only you can see who viewed this story', status: 403);
    }
    return [
      for (final id in story.viewerIds)
        if (_usersById[id] != null) _usersById[id]!,
    ];
  }

  HubStory? _visibleStory(HubUser viewer, String storyId) {
    _pruneStories();
    for (final story in _stories) {
      if (story.id != storyId) continue;
      if (!_canViewStory(viewer, story)) return null;
      return story;
    }
    return null;
  }

  void _rememberViewer(HubStory story, HubUser viewer) {
    final firstLook = !story.seenBy.contains(viewer.id);
    if (firstLook) story.seenBy.add(viewer.id);
    final showInList =
        viewer.id != story.userId && !story.viewerIds.contains(viewer.id);
    if (showInList) story.viewerIds.add(viewer.id);
    if (!firstLook && !showInList) return;
    _emit({viewer.id, if (showInList) story.userId}.toList(), {
      'type': 'story',
      'storyId': story.id,
    });
  }

  String storyVisibilityFor(String token) {
    return _requireUser(token).storyVisibility;
  }

  String setStoryVisibility({
    required String token,
    required String visibility,
  }) {
    if (visibility != 'public' &&
        visibility != 'friends' &&
        visibility != 'onlyMe') {
      throw HubException('Choose public, friends only, or only me');
    }
    final user = _requireUser(token);
    user.storyVisibility = visibility;
    _emit(_usersById.keys.toList(), {'type': 'story'});
    return visibility;
  }

  HubUser addFriend({required String token, required String username}) {
    final me = _requireUser(token);
    final name = username.trim().toLowerCase();
    if (name.isEmpty) throw HubException('Enter a username');
    HubUser? other;
    for (final user in _usersById.values) {
      if (user.displayName.toLowerCase() == name) {
        other = user;
        break;
      }
    }
    if (other == null) {
      throw HubException('No user with that username', status: 404);
    }
    if (other.id == me.id) throw HubException('You cannot add yourself');
    if (me.friendIds.contains(other.id)) {
      throw HubException('Already friends');
    }
    me.friendIds.add(other.id);
    _emit([me.id, other.id], {'type': 'story'});
    return other;
  }

  List<HubUser> friendsFor(String token) {
    final me = _requireUser(token);
    final friends = [
      for (final id in me.friendIds)
        if (_usersById[id] != null) _usersById[id]!,
    ];
    friends.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return friends;
  }

  bool _canViewStory(HubUser viewer, HubStory story) {
    final author = _usersById[story.userId];
    if (author == null) return false;
    if (viewer.id == author.id) return true;
    final visibility = story.visibility ?? author.storyVisibility;
    return switch (visibility) {
      'onlyMe' => false,
      'friends' => author.friendIds.contains(viewer.id),
      _ => true,
    };
  }

  void _pruneStories() {
    final cutoff = _now().toUtc().subtract(const Duration(hours: 24));
    _stories.removeWhere((story) => story.createdAt.isBefore(cutoff));
  }

  HubStoryView _storyView(HubStory story, HubUser viewer) {
    final user = _usersById[story.userId];
    return HubStoryView(
      id: story.id,
      userId: story.userId,
      displayName: user?.displayName ?? 'Someone',
      avatarRevision: user?.avatarRevision ?? 0,
      createdAt: story.createdAt,
      seen: story.seenBy.contains(viewer.id),
    );
  }

  void listen(String token, HubListener listener) {
    final me = _requireUser(token);
    _listeners.putIfAbsent(me.id, () => {}).add(listener);
  }

  void unlisten(String token, HubListener listener) {
    final userId = _userIdByToken[token];
    if (userId == null) return;
    _listeners[userId]?.remove(listener);
  }

  Map<String, Object?> toJson() {
    _pruneStories();
    return {
      'users': _usersById.values.map((user) => user.toJson()).toList(),
      'chats': _chats.values.map((chat) => chat.toJson()).toList(),
      'messages': [
        for (final list in _messages.values)
          for (final message in list) message.toJson(),
      ],
      'reads': [
        for (final chat in _chats.values)
          for (final entry in chat.lastReadAt.entries)
            {
              'chatId': chat.id,
              'userId': entry.key,
              'readAt': entry.value.toIso8601String(),
            },
      ],
      'stories': [for (final story in _stories) story.toJson()],
    };
  }

  void load(Map<String, Object?> json) {
    _usersById.clear();
    _userIdByToken.clear();
    _chats.clear();
    _messages.clear();
    _stories.clear();
    for (final raw in json['users'] as List<dynamic>? ?? const []) {
      final user = HubUser.fromJson(_map(raw));
      _usersById[user.id] = user;
      _userIdByToken[user.token] = user.id;
    }
    for (final raw in json['chats'] as List<dynamic>? ?? const []) {
      final chat = HubChat.fromJson(_map(raw));
      _chats[chat.id] = chat;
    }
    for (final raw in json['messages'] as List<dynamic>? ?? const []) {
      final message = HubMessage.fromJson(_map(raw));
      _messages.putIfAbsent(message.chatId, () => []).add(message);
    }
    for (final raw in json['reads'] as List<dynamic>? ?? const []) {
      final read = _map(raw);
      final chat = _chats[read['chatId']];
      final readAt = read['readAt'];
      final userId = read['userId'];
      if (chat != null && userId is String && readAt is String) {
        chat.lastReadAt[userId] = DateTime.parse(readAt);
      }
    }
    for (final raw in json['stories'] as List<dynamic>? ?? const []) {
      _stories.add(HubStory.fromJson(_map(raw)));
    }
  }

  HubUser _requireUser(String token) {
    final id = _userIdByToken[token];
    final user = id == null ? null : _usersById[id];
    if (user == null) {
      throw HubException('Sign in again', status: 401);
    }
    return user;
  }

  HubChat _requireChat(
    String chatId,
    String userId, {
    bool allowHidden = false,
  }) {
    final chat = _chats[chatId];
    if (chat == null || !chat.participantIds.contains(userId)) {
      throw HubException('Chat not found', status: 404);
    }
    if (!allowHidden && !chat.isVisibleTo(userId)) {
      throw HubException('Chat not found', status: 404);
    }
    return chat;
  }

  HubChatView _view(HubChat chat, String viewerId) {
    final otherId = chat.participantIds.firstWhere((id) => id != viewerId);
    final other = _usersById[otherId];
    return HubChatView(
      id: chat.id,
      title: other?.displayName ?? 'Chat',
      otherUserId: otherId,
      preview: chat.lastMessagePreview,
      lastMessageAt: chat.lastMessageAt,
      unreadCount: _unreadCount(chat, viewerId),
      avatarRevision: other?.avatarRevision ?? 0,
    );
  }

  int _unreadCount(HubChat chat, String viewerId) {
    final readAt = chat.lastReadAt[viewerId];
    final messages = _messages[chat.id] ?? const <HubMessage>[];
    return messages.where((message) {
      if (message.senderId == viewerId) return false;
      if (readAt == null) return true;
      return message.createdAt.isAfter(readAt);
    }).length;
  }

  void _emit(List<String> userIds, Map<String, Object?> event) {
    final payload = jsonEncode(event);
    for (final userId in userIds) {
      for (final listener in _listeners[userId] ?? const <HubListener>{}) {
        listener.send(payload);
      }
    }
  }

  String _id(String prefix) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_$time$salt';
  }
}

class HubListener {
  HubListener(this.send);

  final void Function(String payload) send;
}

class HubException implements Exception {
  HubException(this.message, {this.status = 400});

  final String message;
  final int status;

  @override
  String toString() => message;
}

class HubPushNotice {
  const HubPushNotice({
    required this.tokens,
    required this.title,
    required this.body,
    required this.chatId,
    required this.messageId,
    required this.senderId,
  });

  final Set<String> tokens;
  final String title;
  final String body;
  final String chatId;
  final String messageId;
  final String senderId;
}

class HubUser {
  HubUser({
    required this.id,
    required this.displayName,
    required this.token,
    this.avatar,
    this.avatarRevision = 0,
    this.storyVisibility = 'public',
    this.publicKey,
    Iterable<String> friendIds = const [],
    Iterable<String> fcmTokens = const [],
  }) : friendIds = {...friendIds},
       fcmTokens = {...fcmTokens};

  final String id;
  String displayName;
  final String token;
  Uint8List? avatar;
  int avatarRevision;
  String storyVisibility;
  String? publicKey;
  final Set<String> friendIds;
  final Set<String> fcmTokens;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'token': token,
    'avatarRevision': avatarRevision,
    'storyVisibility': storyVisibility,
    'publicKey': publicKey,
    'friendIds': friendIds.toList(),
    'fcmTokens': fcmTokens.toList(),
    if (avatar != null) 'avatar': base64Encode(avatar!),
  };

  factory HubUser.fromJson(Map<String, Object?> json) {
    final encoded = json['avatar'];
    final friends = json['friendIds'];
    final tokens = json['fcmTokens'];
    return HubUser(
      id: json['id']! as String,
      displayName: json['displayName']! as String,
      token: json['token']! as String,
      avatarRevision: (json['avatarRevision'] as num?)?.toInt() ?? 0,
      publicKey: json['publicKey'] as String?,
      storyVisibility: json['storyVisibility'] as String? ?? 'public',
      friendIds: friends is List
          ? friends.map((id) => id.toString())
          : const [],
      fcmTokens: tokens is List ? tokens.map((id) => id.toString()) : const [],
      avatar: encoded is String ? base64Decode(encoded) : null,
    );
  }
}

class HubChat {
  HubChat({
    required this.id,
    required this.participantIds,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    Iterable<String> hiddenForUserIds = const [],
  }) : hiddenForUserIds = {...hiddenForUserIds};

  final String id;
  final List<String> participantIds;
  String lastMessagePreview;
  DateTime? lastMessageAt;
  final Map<String, DateTime> lastReadAt = {};
  final Set<String> hiddenForUserIds;

  bool isVisibleTo(String userId) => !hiddenForUserIds.contains(userId);

  Map<String, Object?> toJson() => {
    'id': id,
    'participantIds': participantIds,
    'lastMessagePreview': lastMessagePreview,
    'lastMessageAt': lastMessageAt?.toIso8601String(),
    'hiddenForUserIds': hiddenForUserIds.toList(),
  };

  factory HubChat.fromJson(Map<String, Object?> json) {
    return HubChat(
      id: json['id']! as String,
      participantIds: (json['participantIds']! as List<dynamic>).cast<String>(),
      lastMessagePreview: json['lastMessagePreview'] as String? ?? '',
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt']! as String),
      hiddenForUserIds: [
        for (final id in json['hiddenForUserIds'] as List<dynamic>? ?? const [])
          if (id is String) id,
      ],
    );
  }
}

class HubChatView {
  const HubChatView({
    required this.id,
    required this.title,
    required this.otherUserId,
    required this.preview,
    required this.lastMessageAt,
    required this.unreadCount,
    this.avatarRevision = 0,
  });

  final String id;
  final String title;
  final String otherUserId;
  final String preview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final int avatarRevision;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'otherUserId': otherUserId,
    'preview': preview,
    'lastMessageAt': lastMessageAt?.toIso8601String(),
    'unreadCount': unreadCount,
    'avatarRevision': avatarRevision,
  };
}

class HubMessage {
  const HubMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'chatId': chatId,
    'senderId': senderId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory HubMessage.fromJson(Map<String, Object?> json) {
    return HubMessage(
      id: json['id']! as String,
      chatId: json['chatId']! as String,
      senderId: json['senderId']! as String,
      text: json['text']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }
}

class HubStory {
  HubStory({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.image,
    this.visibility,
    List<String>? viewerIds,
    List<String>? seenBy,
  }) : viewerIds = viewerIds ?? [],
       seenBy = seenBy ?? List<String>.from(viewerIds ?? const []);

  final String id;
  final String userId;
  DateTime createdAt;
  final Uint8List image;

  /// Null keeps older stories on the author's account setting.
  final String? visibility;
  final List<String> viewerIds;

  /// People who opened the story, including the author.
  final List<String> seenBy;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'image': base64Encode(image),
    'visibility': visibility,
    'viewerIds': viewerIds,
    'seenBy': seenBy,
  };

  factory HubStory.fromJson(Map<String, Object?> json) {
    return HubStory(
      id: json['id']! as String,
      userId: json['userId']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      image: base64Decode(json['image']! as String),
      visibility: json['visibility'] as String?,
      viewerIds: [
        for (final id in json['viewerIds'] as List<dynamic>? ?? const [])
          if (id is String) id,
      ],
      seenBy: [
        for (final id
            in (json['seenBy'] ?? json['viewerIds']) as List<dynamic>? ??
                const [])
          if (id is String) id,
      ],
    );
  }
}

class HubStoryView {
  const HubStoryView({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.avatarRevision,
    required this.createdAt,
    this.seen = false,
  });

  final String id;
  final String userId;
  final String displayName;
  final int avatarRevision;
  final DateTime createdAt;
  final bool seen;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'avatarRevision': avatarRevision,
    'createdAt': createdAt.toIso8601String(),
    'seen': seen,
  };
}

Map<String, Object?> _map(Object? raw) {
  return (raw as Map).map((key, value) => MapEntry(key.toString(), value));
}
