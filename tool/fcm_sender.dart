import 'dart:convert';
import 'dart:io';

/// Sends FCM push notifications using a legacy server key.
///
/// Set `FCM_SERVER_KEY` (Firebase Console → Project settings → Cloud Messaging
/// → Server key / Cloud Messaging API key) before starting the chat server.
class FcmSender {
  FcmSender({String? serverKey, HttpClient? client})
    : _serverKey = serverKey ?? Platform.environment['FCM_SERVER_KEY'] ?? '',
      _client = client ?? HttpClient();

  final String _serverKey;
  final HttpClient _client;

  bool get isConfigured => _serverKey.trim().isNotEmpty;

  Future<void> sendMessage({
    required Iterable<String> tokens,
    required String title,
    required String body,
    required String chatId,
    required String messageId,
    required String senderId,
  }) async {
    if (!isConfigured) return;
    final unique = tokens
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toSet();
    for (final token in unique) {
      await _post({
        'to': token,
        'priority': 'high',
        'content_available': true,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'android_channel_id': 'chat_messages',
        },
        'data': {
          'chatId': chatId,
          'messageId': messageId,
          'senderId': senderId,
          'title': title,
          'body': body,
        },
      });
    }
  }

  Future<void> _post(Map<String, Object?> payload) async {
    try {
      final request = await _client.postUrl(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'key=$_serverKey');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      await response.drain<void>();
    } catch (error) {
      stderr.writeln('FCM push failed: $error');
    }
  }
}
