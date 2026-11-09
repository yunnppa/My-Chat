import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';
import 'message_crypto.dart';

class HttpChatRepository implements ChatRepository {
  HttpChatRepository({
    required this.baseUrl,
    required this._crypto,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final MessageCrypto _crypto;
  final http.Client _client;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _peerKeys = <String, String>{};
  final _chatPeers = <String, String>{};
  WebSocketChannel? _socket;
  String? _socketToken;

  @override
  Future<AppSession> register({
    required String displayName,
    String? token,
  }) async {
    final json = await _post('/v1/users', {
      'displayName': displayName,
      'token': token,
    });
    return AppSession(
      userId: json['id']! as String,
      displayName: json['displayName']! as String,
      token: json['token']! as String,
    );
  }

  @override
  Stream<List<ChatSummary>> watchChats(AppSession session) async* {
    _connect(session);
    yield await _fetchChats(session);
    yield* _events.stream.asyncMap((_) => _fetchChats(session));
  }

  @override
  Stream<IncomingNotice> incomingMessages(AppSession session) async* {
    _connect(session);
    await for (final event in _events.stream) {
      final notice = await _incoming(event, session);
      if (notice != null) yield notice;
    }
  }

  Future<IncomingNotice?> _incoming(
    Map<String, Object?> event,
    AppSession session,
  ) async {
    if (event['type'] != 'message') return null;
    final raw = event['message'];
    if (raw is! Map) return null;
    final message = raw.map((key, value) => MapEntry('$key', value));
    final senderId = message['senderId'] as String? ?? '';
    if (senderId.isEmpty || senderId == session.userId) return null;
    final text = (message['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    return IncomingNotice(
      chatId: message['chatId'] as String? ?? event['chatId'] as String? ?? '',
      messageId: message['id'] as String? ?? '',
      senderId: senderId,
      senderName: event['senderName'] as String? ?? 'New message',
      text: await _decryptText(
        session: session,
        peerUserId: senderId,
        text: text,
      ),
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(
    AppSession session,
    String chatId,
  ) async* {
    _connect(session);
    yield await _fetchMessages(session, chatId);
    yield* _events.stream
        .where((event) => event['chatId'] == chatId)
        .asyncMap((_) => _fetchMessages(session, chatId));
  }

  @override
  Future<List<ChatPerson>> searchPeople(
    AppSession session,
    String query,
  ) async {
    final json = await _get('/v1/users', session: session, query: {'q': query});
    return [
      for (final raw in json['users']! as List<dynamic>)
        ChatPerson(
          id: (raw as Map)['id'] as String,
          displayName: raw['displayName'] as String,
          avatarRevision: (raw['avatarRevision'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<ChatSummary> openDirectChat({
    required AppSession session,
    required String otherUserId,
  }) async {
    final json = await _post('/v1/chats', {
      'otherUserId': otherUserId,
    }, session: session);
    final chat = await _chat(json, session: session);
    _chatPeers[chat.id] = chat.otherUserId;
    return chat;
  }

  @override
  Future<ChatMessage> sendMessage({
    required AppSession session,
    required String chatId,
    required String otherUserId,
    required String text,
  }) async {
    if (otherUserId.isNotEmpty) _chatPeers[chatId] = otherUserId;
    final peerKey = await _peerPublicKey(session, otherUserId);
    final wire = peerKey == null
        ? text
        : await _crypto.encrypt(plaintext: text, peerPublicKey: peerKey);
    final json = await _post('/v1/chats/$chatId/messages', {
      'text': wire,
    }, session: session);
    final message = await _message(
      json,
      session: session,
      peerUserId: otherUserId,
    );
    return ChatMessage(
      id: message.id,
      chatId: message.chatId,
      senderId: message.senderId,
      text: text,
      createdAt: message.createdAt,
    );
  }

  @override
  Future<void> markRead({
    required AppSession session,
    required String chatId,
  }) async {
    await _post('/v1/chats/$chatId/read', const {}, session: session);
  }

  @override
  Future<void> deleteConversation({
    required AppSession session,
    required String chatId,
    required ChatDeleteScope scope,
  }) async {
    await _send(
      () => _client.delete(
        _uri('/v1/chats/$chatId', {'scope': scope.wire}),
        headers: _headers(session),
      ),
    );
  }

  @override
  Future<void> publishEncryptionKey(AppSession session) async {
    final publicKey = await _crypto.localPublicKey();
    await _post('/v1/users/me/public-key', {
      'publicKey': publicKey,
    }, session: session);
  }

  @override
  Future<void> registerPushToken({
    required AppSession session,
    required String token,
  }) async {
    await _post('/v1/users/me/push-token', {'token': token}, session: session);
  }

  @override
  Future<void> uploadAvatar({
    required AppSession session,
    required Uint8List bytes,
  }) async {
    await _send(
      () => _client.post(
        _uri('/v1/users/avatar'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'image/jpeg',
        },
        body: bytes,
      ),
    );
  }

  @override
  Future<Uint8List?> downloadAvatar(String userId) async {
    final http.Response response;
    try {
      response = await _client
          .get(_uri('/v1/users/$userId/avatar'))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 400) return null;
    if (response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  @override
  Stream<List<StorySummary>> watchStories(AppSession session) async* {
    _connect(session);
    yield await _fetchStories(session);
    yield* _events.stream.asyncMap((_) => _fetchStories(session));
  }

  @override
  Future<StorySummary> uploadStory({
    required AppSession session,
    required Uint8List bytes,
    required StoryVisibility visibility,
  }) async {
    final json = await _send(
      () => _client.post(
        _uri('/v1/stories', {'visibility': visibility.wire}),
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'image/jpeg',
        },
        body: bytes,
      ),
    );
    return _story(json);
  }

  @override
  Future<void> markStoryViewed({
    required AppSession session,
    required String storyId,
  }) async {
    await _post(
      '/v1/stories/$storyId/view',
      <String, Object?>{},
      session: session,
    );
  }

  @override
  Future<List<ChatPerson>> storyViewers({
    required AppSession session,
    required String storyId,
  }) async {
    final json = await _get('/v1/stories/$storyId/viewers', session: session);
    return [
      for (final raw in json['viewers']! as List<dynamic>)
        ChatPerson(
          id: (raw as Map)['id'] as String,
          displayName: raw['displayName'] as String,
          avatarRevision: (raw['avatarRevision'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<List<ChatPerson>> listFriends(AppSession session) async {
    final json = await _get('/v1/friends', session: session);
    return [
      for (final raw in json['friends']! as List<dynamic>)
        ChatPerson(
          id: (raw as Map)['id'] as String,
          displayName: raw['displayName'] as String,
          avatarRevision: (raw['avatarRevision'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<ChatPerson> addFriend({
    required AppSession session,
    required String username,
  }) async {
    final json = await _post('/v1/friends', {
      'username': username,
    }, session: session);
    return ChatPerson(
      id: json['id']! as String,
      displayName: json['displayName']! as String,
      avatarRevision: (json['avatarRevision'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<StoryVisibility> storyVisibility(AppSession session) async {
    final json = await _get('/v1/users/me', session: session);
    return StoryVisibility.parse(json['storyVisibility'] as String?);
  }

  @override
  Future<void> setStoryVisibility({
    required AppSession session,
    required StoryVisibility visibility,
  }) async {
    await _post('/v1/users/me/story-visibility', {
      'visibility': visibility.wire,
    }, session: session);
  }

  Future<List<StorySummary>> _fetchStories(AppSession session) async {
    final json = await _get('/v1/stories', session: session);
    return [
      for (final raw in json['stories']! as List<dynamic>)
        _story((raw as Map).cast<String, Object?>()),
    ];
  }

  StorySummary _story(Map<String, Object?> json) {
    return StorySummary(
      id: json['id']! as String,
      userId: json['userId']! as String,
      displayName: json['displayName']! as String,
      avatarRevision: (json['avatarRevision'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt']! as String),
      seen: json['seen'] == true,
    );
  }

  @override
  void dispose() {
    _socket?.sink.close();
    _client.close();
    _events.close();
  }

  void _connect(AppSession session) {
    if (_socketToken == session.token && _socket != null) return;
    _socket?.sink.close();
    _socketToken = session.token;
    final channel = WebSocketChannel.connect(_wsUri(session.token));
    _socket = channel;
    channel.stream.listen(
      (raw) {
        final decoded = jsonDecode(raw as String);
        if (decoded is Map && !_events.isClosed) {
          _events.add(decoded.map((key, value) => MapEntry('$key', value)));
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_events.isClosed) _events.addError(error, stack);
      },
    );
  }

  Future<List<ChatSummary>> _fetchChats(AppSession session) async {
    final json = await _get('/v1/chats', session: session);
    final chats = <ChatSummary>[];
    for (final raw in json['chats']! as List<dynamic>) {
      final chat = await _chat(
        (raw as Map).cast<String, Object?>(),
        session: session,
      );
      _chatPeers[chat.id] = chat.otherUserId;
      chats.add(chat);
    }
    return chats;
  }

  Future<List<ChatMessage>> _fetchMessages(
    AppSession session,
    String chatId,
  ) async {
    final json = await _get('/v1/chats/$chatId/messages', session: session);
    var otherUserId = _chatPeers[chatId] ?? '';
    if (otherUserId.isEmpty) {
      final chats = await _fetchChats(session);
      otherUserId =
          chats
              .where((chat) => chat.id == chatId)
              .map((chat) => chat.otherUserId)
              .firstOrNull ??
          '';
    }
    final messages = <ChatMessage>[];
    for (final raw in json['messages']! as List<dynamic>) {
      messages.add(
        await _message(
          (raw as Map).cast<String, Object?>(),
          session: session,
          peerUserId: otherUserId,
        ),
      );
    }
    return messages;
  }

  Future<String?> _peerPublicKey(AppSession session, String userId) async {
    if (userId.isEmpty) return null;
    final cached = _peerKeys[userId];
    if (cached != null) return cached;
    try {
      final json = await _get('/v1/users/$userId/public-key', session: session);
      final key = json['publicKey'] as String?;
      if (key == null || key.isEmpty) return null;
      _peerKeys[userId] = key;
      return key;
    } on ChatApiException {
      return null;
    }
  }

  Future<String> _decryptText({
    required AppSession session,
    required String peerUserId,
    required String text,
  }) async {
    if (!MessageCrypto.isEncrypted(text)) return text;
    final peerKey = await _peerPublicKey(session, peerUserId);
    if (peerKey == null) return 'Encrypted message';
    try {
      return await _crypto.decrypt(ciphertext: text, peerPublicKey: peerKey);
    } catch (_) {
      return 'Unable to decrypt';
    }
  }

  Future<Map<String, Object?>> _get(
    String path, {
    required AppSession session,
    Map<String, String>? query,
  }) {
    return _send(
      () => _client.get(_uri(path, query), headers: _headers(session)),
    );
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, {
    AppSession? session,
  }) {
    return _send(
      () => _client.post(
        _uri(path),
        headers: _headers(session),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, Object?>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ChatApiException(
        'The chat server did not respond. Start it with '
        'dart run tool/chat_server.dart',
      );
    } catch (error) {
      if (error is ChatApiException) rethrow;
      throw ChatApiException(
        'Cannot reach the chat server at $baseUrl. '
        'On a phone, set this computer\'s address in Settings.',
      );
    }
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : (jsonDecode(response.body) as Map).map(
            (key, value) => MapEntry('$key', value),
          );
    if (response.statusCode >= 400) {
      throw ChatApiException(decoded['error'] as String? ?? 'Request failed');
    }
    return decoded;
  }

  Map<String, String> _headers(AppSession? session) {
    return {
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session.token}',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Uri _wsUri(String token) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/v1/ws',
      queryParameters: {'token': token},
    );
  }

  Future<ChatSummary> _chat(
    Map<String, Object?> json, {
    required AppSession session,
  }) async {
    final otherUserId = json['otherUserId']! as String;
    final preview = json['preview'] as String? ?? '';
    return ChatSummary(
      id: json['id']! as String,
      title: json['title']! as String,
      otherUserId: otherUserId,
      preview: preview == 'Encrypted message'
          ? preview
          : await _decryptText(
              session: session,
              peerUserId: otherUserId,
              text: preview,
            ),
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt']! as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      avatarRevision: (json['avatarRevision'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ChatMessage> _message(
    Map<String, Object?> json, {
    required AppSession session,
    required String peerUserId,
  }) async {
    final text = json['text']! as String;
    return ChatMessage(
      id: json['id']! as String,
      chatId: json['chatId']! as String,
      senderId: json['senderId']! as String,
      text: await _decryptText(
        session: session,
        peerUserId: peerUserId,
        text: text,
      ),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }
}

class ChatApiException implements Exception {
  ChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
