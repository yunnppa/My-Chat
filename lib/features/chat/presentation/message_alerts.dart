import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';

const _messagesChannel = 'chat_messages';
const _seenPrefix = 'seen_message_';

bool get _underTest => Platform.environment['FLUTTER_TEST'] == 'true';

final _notifications = FlutterLocalNotificationsPlugin();

/// Shows a message notification and keeps listening while the app is away.
class MessageAlertHost extends ConsumerStatefulWidget {
  const MessageAlertHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MessageAlertHost> createState() => _MessageAlertHostState();
}

class _MessageAlertHostState extends ConsumerState<MessageAlertHost>
    with WidgetsBindingObserver {
  StreamSubscription<IncomingNotice>? _incoming;
  var _inUse = true;
  String? _listeningFor;
  String? _serviceKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_underTest) {
      FlutterForegroundTask.initCommunicationPort();
      _prepare();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incoming?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inUse = state == AppLifecycleState.resumed;
    if (_underTest) return;
    FlutterForegroundTask.saveData(key: 'app_in_use', value: _inUse);
  }

  Future<void> _prepare() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'chat_connection',
        channelName: 'Message connection',
        channelDescription: 'Keeps ChatApp able to receive messages',
        channelImportance: NotificationChannelImportance.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(4000),
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) _open(payload);
        },
      );
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _messagesChannel,
          'Messages',
          description: 'New chat messages',
          importance: Importance.high,
        ),
      );
      await FlutterForegroundTask.requestNotificationPermission();
      final launch = await _notifications.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && payload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(payload));
      }
    } catch (_) {}
  }

  void _open(String payload) {
    final split = payload.indexOf('|');
    if (split <= 0) return;
    final chatId = payload.substring(0, split);
    final title = Uri.decodeComponent(payload.substring(split + 1));
    ref
        .read(appRouterProvider)
        .push('/chat/$chatId?title=${Uri.encodeComponent(title)}');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final baseUrl = ref.watch(apiBaseProvider);
    if (session?.userId != _listeningFor) {
      _listeningFor = session?.userId;
      _bindIncoming(session);
    }
    final serviceKey = session == null ? '' : '${session.token}|$baseUrl';
    if (!_underTest && serviceKey != _serviceKey) {
      _serviceKey = serviceKey;
      _syncService(session, baseUrl);
    }
    return widget.child;
  }

  void _bindIncoming(AppSession? session) {
    _incoming?.cancel();
    _incoming = null;
    if (session == null) return;
    _incoming = ref
        .read(chatRepositoryProvider)
        .incomingMessages(session)
        .listen((notice) {
          if (_inUse) {
            FlutterForegroundTask.saveData(
              key: '$_seenPrefix${notice.chatId}',
              value: notice.messageId,
            );
            return;
          }
          showMessageAlert(notice);
        });
  }

  Future<void> _syncService(AppSession? session, String baseUrl) async {
    try {
      if (session == null) {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
        return;
      }
      await FlutterForegroundTask.saveData(key: 'app_in_use', value: _inUse);
      await FlutterForegroundTask.saveData(
        key: 'session_token',
        value: session.token,
      );
      await FlutterForegroundTask.saveData(
        key: 'user_id',
        value: session.userId,
      );
      await FlutterForegroundTask.saveData(key: 'api_base', value: baseUrl);
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.dataSync],
        serviceId: 256,
        notificationTitle: 'ChatApp',
        notificationText: 'Listening for messages',
        callback: messageAlertCallback,
      );
    } catch (_) {}
  }
}

Future<void> showMessageAlert(
  IncomingNotice notice, {
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  if (notice.messageId.isEmpty || notice.chatId.isEmpty) return;
  final seen = await FlutterForegroundTask.getData<String>(
    key: '$_seenPrefix${notice.chatId}',
  );
  if (seen == notice.messageId) return;
  await FlutterForegroundTask.saveData(
    key: '$_seenPrefix${notice.chatId}',
    value: notice.messageId,
  );
  final payload = '${notice.chatId}|${Uri.encodeComponent(notice.senderName)}';
  try {
    await (plugin ?? _notifications).show(
      id: notice.messageId.hashCode & 0x7fffffff,
      title: notice.senderName,
      body: notice.text,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel,
          'Messages',
          channelDescription: 'New chat messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  } catch (_) {}
}

@pragma('vm:entry-point')
void messageAlertCallback() {
  FlutterForegroundTask.setTaskHandler(MessageAlertTask());
}

class MessageAlertTask extends TaskHandler {
  final _client = HttpClient();
  var _busy = false;
  var _primed = false;
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    } catch (_) {}
    await _poll();
    _primed = true;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_busy) return;
    _busy = true;
    _poll().whenComplete(() => _busy = false);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _client.close(force: true);
  }

  Future<void> _poll() async {
    final token = await FlutterForegroundTask.getData<String>(
      key: 'session_token',
    );
    final userId = await FlutterForegroundTask.getData<String>(key: 'user_id');
    final base = await FlutterForegroundTask.getData<String>(key: 'api_base');
    if (token == null || userId == null || base == null || base.isEmpty) {
      return;
    }
    final inUse =
        await FlutterForegroundTask.getData<bool>(key: 'app_in_use') ?? true;
    final chats = await _get(base, token, '/v1/chats');
    final list = chats?['chats'];
    if (list is! List) return;
    for (final raw in list) {
      if (raw is! Map) continue;
      final chat = raw.map((key, value) => MapEntry('$key', value));
      final unread = (chat['unreadCount'] as num?)?.toInt() ?? 0;
      final chatId = chat['id'] as String? ?? '';
      final title = chat['title'] as String? ?? 'New message';
      if (chatId.isEmpty || unread <= 0) continue;
      final body = await _get(base, token, '/v1/chats/$chatId/messages');
      final messages = body?['messages'];
      if (messages is! List) continue;
      Map<String, Object?>? latest;
      for (final item in messages) {
        if (item is! Map) continue;
        final message = item.map((key, value) => MapEntry('$key', value));
        if (message['senderId'] == userId) continue;
        latest = message;
      }
      if (latest == null) continue;
      final notice = IncomingNotice(
        chatId: chatId,
        messageId: latest['id'] as String? ?? '',
        senderId: latest['senderId'] as String? ?? '',
        senderName: title,
        text: (latest['text'] as String? ?? '').trim(),
      );
      if (!_primed || inUse) {
        await FlutterForegroundTask.saveData(
          key: '$_seenPrefix$chatId',
          value: notice.messageId,
        );
        continue;
      }
      await showMessageAlert(notice, plugin: _plugin);
    }
  }

  Future<Map<String, Object?>?> _get(
    String base,
    String token,
    String path,
  ) async {
    try {
      final request = await _client.getUrl(Uri.parse('$base$path'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400 || text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry('$key', value));
    } catch (_) {
      return null;
    }
  }
}
