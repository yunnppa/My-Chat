import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chat_hub.dart';
import 'fcm_sender.dart';

/// Local realtime chat server.
///
/// Run from the project root:
/// `dart run tool/chat_server.dart`
///
/// The simulator can use http://127.0.0.1:8080.
/// A phone on the same Wi-Fi should use this computer's LAN address,
/// which is printed when the server starts. Set that address in
/// Settings inside the app.
Future<void> main() async {
  final hub = ChatHub();
  final fcm = FcmSender();
  final store = File('tool/chat_data.json');
  if (store.existsSync()) {
    final decoded = jsonDecode(store.readAsStringSync());
    if (decoded is Map) {
      hub.load(decoded.map((key, value) => MapEntry('$key', value)));
    }
  }

  Future<void> persist() async {
    await store.writeAsString(
      const JsonEncoder.withIndent('  ').convert(hub.toJson()),
    );
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  stdout.writeln('Chat server listening on port ${server.port}');
  for (final interface in await NetworkInterface.list()) {
    for (final address in interface.addresses) {
      if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
        stdout.writeln('  phone URL: http://${address.address}:${server.port}');
      }
    }
  }
  stdout.writeln('  simulator URL: http://127.0.0.1:${server.port}');
  if (fcm.isConfigured) {
    stdout.writeln('  FCM push: enabled (FCM_SERVER_KEY set)');
  } else {
    stdout.writeln(
      '  FCM push: disabled — set FCM_SERVER_KEY to send background pushes',
    );
  }

  await for (final request in server) {
    try {
      if (request.method == 'OPTIONS') {
        _cors(request.response);
        await request.response.close();
        continue;
      }
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        await _socket(request, hub);
        continue;
      }
      await _route(request, hub, persist, fcm);
    } catch (error, stack) {
      stderr.writeln('$error\n$stack');
      try {
        _json(request.response, HttpStatus.internalServerError, {
          'error': 'Server error',
        });
        await request.response.close();
      } catch (_) {}
    }
  }
}

Future<void> _socket(HttpRequest request, ChatHub hub) async {
  final token = request.uri.queryParameters['token'];
  if (token == null || token.isEmpty) {
    request.response.statusCode = HttpStatus.unauthorized;
    await request.response.close();
    return;
  }
  final socket = await WebSocketTransformer.upgrade(request);
  late final HubListener listener;
  listener = HubListener((payload) => socket.add(payload));
  try {
    hub.listen(token, listener);
  } on HubException {
    await socket.close(WebSocketStatus.policyViolation);
    return;
  }
  socket.listen(
    (_) {},
    onDone: () => hub.unlisten(token, listener),
    onError: (_) => hub.unlisten(token, listener),
  );
}

Future<void> _route(
  HttpRequest request,
  ChatHub hub,
  Future<void> Function() persist,
  FcmSender fcm,
) async {
  final path = request.uri.path;
  final token = _bearer(request);

  try {
    if (request.method == 'POST' && path == '/v1/users') {
      final body = await _body(request);
      final user = hub.register(
        token: body['token'] as String?,
        displayName: body['displayName'] as String? ?? '',
      );
      await persist();
      _json(request.response, HttpStatus.ok, {
        'id': user.id,
        'displayName': user.displayName,
        'token': user.token,
      });
    } else if (request.method == 'GET' && path == '/v1/users') {
      final users = hub.searchUsers(
        token: _requireToken(token),
        query: request.uri.queryParameters['q'] ?? '',
      );
      _json(request.response, HttpStatus.ok, {
        'users': [
          for (final user in users)
            {
              'id': user.id,
              'displayName': user.displayName,
              'avatarRevision': user.avatarRevision,
            },
        ],
      });
    } else if (request.method == 'POST' && path == '/v1/users/avatar') {
      final bytes = await _bytes(request);
      final revision = hub.setAvatar(token: _requireToken(token), bytes: bytes);
      await persist();
      _json(request.response, HttpStatus.ok, {'avatarRevision': revision});
    } else if (request.method == 'GET' &&
        path.startsWith('/v1/users/') &&
        path.endsWith('/avatar')) {
      final userId = path.split('/')[3];
      final bytes = hub.avatarOf(userId);
      if (bytes == null) {
        _json(request.response, HttpStatus.notFound, {'error': 'No photo'});
      } else {
        _cors(request.response);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.headers.set('Cache-Control', 'public, max-age=86400');
        request.response.add(bytes);
      }
    } else if (request.method == 'GET' && path == '/v1/users/me') {
      _json(request.response, HttpStatus.ok, {
        'storyVisibility': hub.storyVisibilityFor(_requireToken(token)),
      });
    } else if (request.method == 'POST' && path == '/v1/users/me/public-key') {
      final body = await _body(request);
      hub.setPublicKey(
        token: _requireToken(token),
        publicKey: body['publicKey'] as String? ?? '',
      );
      await persist();
      _json(request.response, HttpStatus.ok, {'ok': true});
    } else if (request.method == 'POST' && path == '/v1/users/me/push-token') {
      final body = await _body(request);
      hub.registerPushToken(
        token: _requireToken(token),
        fcmToken: body['token'] as String? ?? '',
      );
      await persist();
      _json(request.response, HttpStatus.ok, {'ok': true});
    } else if (request.method == 'GET' &&
        path.startsWith('/v1/users/') &&
        path.endsWith('/public-key')) {
      final userId = path.split('/')[3];
      _requireToken(token);
      final publicKey = hub.publicKeyOf(userId);
      if (publicKey == null || publicKey.isEmpty) {
        _json(request.response, HttpStatus.notFound, {
          'error': 'No public key',
        });
      } else {
        _json(request.response, HttpStatus.ok, {'publicKey': publicKey});
      }
    } else if (request.method == 'POST' &&
        path == '/v1/users/me/story-visibility') {
      final body = await _body(request);
      final visibility = hub.setStoryVisibility(
        token: _requireToken(token),
        visibility: body['visibility'] as String? ?? '',
      );
      await persist();
      _json(request.response, HttpStatus.ok, {'storyVisibility': visibility});
    } else if (request.method == 'GET' && path == '/v1/friends') {
      _json(request.response, HttpStatus.ok, {
        'friends': [
          for (final friend in hub.friendsFor(_requireToken(token)))
            {
              'id': friend.id,
              'displayName': friend.displayName,
              'avatarRevision': friend.avatarRevision,
            },
        ],
      });
    } else if (request.method == 'POST' && path == '/v1/friends') {
      final body = await _body(request);
      final friend = hub.addFriend(
        token: _requireToken(token),
        username: body['username'] as String? ?? '',
      );
      await persist();
      _json(request.response, HttpStatus.ok, {
        'id': friend.id,
        'displayName': friend.displayName,
        'avatarRevision': friend.avatarRevision,
      });
    } else if (request.method == 'GET' && path == '/v1/stories') {
      _json(request.response, HttpStatus.ok, {
        'stories': [
          for (final story in hub.storiesFor(_requireToken(token)))
            story.toJson(),
        ],
      });
    } else if (request.method == 'POST' && path == '/v1/stories') {
      final bytes = await _bytes(request);
      final story = hub.addStory(
        token: _requireToken(token),
        bytes: bytes,
        visibility: request.uri.queryParameters['visibility'],
      );
      await persist();
      _json(request.response, HttpStatus.ok, story.toJson());
    } else if (request.method == 'POST' &&
        path.startsWith('/v1/stories/') &&
        path.endsWith('/view')) {
      final storyId = path.split('/')[3];
      hub.recordStoryView(token: _requireToken(token), storyId: storyId);
      await persist();
      _json(request.response, HttpStatus.ok, {'ok': true});
    } else if (request.method == 'GET' &&
        path.startsWith('/v1/stories/') &&
        path.endsWith('/viewers')) {
      final storyId = path.split('/')[3];
      _json(request.response, HttpStatus.ok, {
        'viewers': [
          for (final viewer in hub.storyViewers(
            token: _requireToken(token),
            storyId: storyId,
          ))
            {
              'id': viewer.id,
              'displayName': viewer.displayName,
              'avatarRevision': viewer.avatarRevision,
            },
        ],
      });
    } else if (request.method == 'GET' &&
        path.startsWith('/v1/stories/') &&
        path.endsWith('/image')) {
      final storyId = path.split('/')[3];
      final imageToken = request.uri.queryParameters['token'] ?? token;
      final bytes = hub.storyImage(
        token: _requireToken(imageToken),
        storyId: storyId,
      );
      if (bytes == null) {
        _json(request.response, HttpStatus.notFound, {'error': 'No story'});
      } else {
        _cors(request.response);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.headers.set('Cache-Control', 'public, max-age=3600');
        request.response.add(bytes);
      }
    } else if (request.method == 'GET' && path == '/v1/chats') {
      _json(request.response, HttpStatus.ok, {
        'chats': [
          for (final chat in hub.chatsFor(_requireToken(token))) chat.toJson(),
        ],
      });
    } else if (request.method == 'POST' && path == '/v1/chats') {
      final body = await _body(request);
      final chat = hub.openDirect(
        token: _requireToken(token),
        otherUserId: body['otherUserId'] as String? ?? '',
      );
      await persist();
      _json(request.response, HttpStatus.ok, chat.toJson());
    } else if (request.method == 'DELETE' &&
        path.startsWith('/v1/chats/') &&
        path.split('/').length == 4) {
      final chatId = path.split('/')[3];
      final scope = request.uri.queryParameters['scope'] ?? 'both';
      hub.deleteChat(token: _requireToken(token), chatId: chatId, scope: scope);
      await persist();
      _json(request.response, HttpStatus.ok, {'ok': true});
    } else if (request.method == 'POST' &&
        path.startsWith('/v1/chats/') &&
        path.endsWith('/read')) {
      final chatId = path.split('/')[3];
      final chat = hub.markRead(token: _requireToken(token), chatId: chatId);
      await persist();
      _json(request.response, HttpStatus.ok, chat.toJson());
    } else if (request.method == 'GET' &&
        path.startsWith('/v1/chats/') &&
        path.endsWith('/messages')) {
      final chatId = path.split('/')[3];
      _json(request.response, HttpStatus.ok, {
        'messages': [
          for (final message in hub.messages(
            token: _requireToken(token),
            chatId: chatId,
          ))
            message.toJson(),
        ],
      });
    } else if (request.method == 'POST' &&
        path.startsWith('/v1/chats/') &&
        path.endsWith('/messages')) {
      final chatId = path.split('/')[3];
      final body = await _body(request);
      final authToken = _requireToken(token);
      final message = hub.send(
        token: authToken,
        chatId: chatId,
        text: body['text'] as String? ?? '',
      );
      await persist();
      final notice = hub.pushNoticeForMessage(
        senderId: message.senderId,
        message: message,
      );
      if (notice != null) {
        // Fire-and-forget so the HTTP reply is not blocked by FCM.
        unawaited(
          fcm.sendMessage(
            tokens: notice.tokens,
            title: notice.title,
            body: notice.body,
            chatId: notice.chatId,
            messageId: notice.messageId,
            senderId: notice.senderId,
          ),
        );
      }
      _json(request.response, HttpStatus.ok, message.toJson());
    } else {
      _json(request.response, HttpStatus.notFound, {'error': 'Not found'});
    }
  } on HubException catch (error) {
    _json(request.response, error.status, {'error': error.message});
  }
  await request.response.close();
}

String? _bearer(HttpRequest request) {
  final header = request.headers.value(HttpHeaders.authorizationHeader);
  if (header == null || !header.startsWith('Bearer ')) return null;
  return header.substring('Bearer '.length);
}

String _requireToken(String? token) {
  if (token == null || token.isEmpty) {
    throw HubException('Sign in again', status: 401);
  }
  return token;
}

Future<List<int>> _bytes(HttpRequest request) {
  return request.fold<List<int>>(
    <int>[],
    (bytes, chunk) => bytes..addAll(chunk),
  );
}

Future<Map<String, Object?>> _body(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.isEmpty) return {};
  return (jsonDecode(raw) as Map).map(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _json(HttpResponse response, int status, Object body) {
  _cors(response);
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
}

void _cors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Authorization, Content-Type',
  );
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}
