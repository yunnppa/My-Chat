import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../../../firebase_options.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';
import 'message_alerts.dart';

bool get _underTest => Platform.environment['FLUTTER_TEST'] == 'true';

var _firebaseReady = false;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<bool> ensureFirebaseMessaging() async {
  if (_underTest || _firebaseReady) return _firebaseReady;
  if (!DefaultFirebaseOptions.isConfigured) return false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _firebaseReady = true;
  } catch (_) {
    _firebaseReady = false;
  }
  return _firebaseReady;
}

/// Registers the FCM device token and shows/opens push notifications.
class PushNotificationHost extends ConsumerStatefulWidget {
  const PushNotificationHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushNotificationHost> createState() =>
      _PushNotificationHostState();
}

class _PushNotificationHostState extends ConsumerState<PushNotificationHost> {
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  String? _registeredFor;
  var _started = false;

  @override
  void initState() {
    super.initState();
    if (!_underTest) {
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    _tokenRefresh?.cancel();
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final ready = await ensureFirebaseMessaging();
    if (!ready || !mounted) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foreground = FirebaseMessaging.onMessage.listen(_onForeground);
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    final initial = await messaging.getInitialMessage();
    if (initial != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openMessage(initial),
      );
    }

    _tokenRefresh = messaging.onTokenRefresh.listen((token) {
      final session = ref.read(sessionProvider);
      if (session != null) unawaited(_registerToken(session, token));
    });

    _started = true;
    final session = ref.read(sessionProvider);
    if (session != null) await _syncToken(session);
  }

  Future<void> _syncToken(AppSession session) async {
    if (!_started) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(session, token);
    } catch (_) {}
  }

  Future<void> _registerToken(AppSession session, String token) async {
    if (_registeredFor == '${session.userId}|$token') return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .registerPushToken(session: session, token: token);
      _registeredFor = '${session.userId}|$token';
    } catch (_) {}
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final notice = _noticeFrom(message);
    if (notice == null) return;
    final inUse =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (inUse) return;
    await showMessageAlert(notice);
  }

  void _openMessage(RemoteMessage message) {
    final chatId = message.data['chatId']?.toString() ?? '';
    if (chatId.isEmpty) return;
    final title =
        message.data['title']?.toString() ??
        message.notification?.title ??
        'Chat';
    ref
        .read(appRouterProvider)
        .push('/chat/$chatId?title=${Uri.encodeComponent(title)}');
  }

  IncomingNotice? _noticeFrom(RemoteMessage message) {
    final chatId = message.data['chatId']?.toString() ?? '';
    final messageId =
        message.data['messageId']?.toString() ?? message.messageId ?? '';
    if (chatId.isEmpty || messageId.isEmpty) return null;
    return IncomingNotice(
      chatId: chatId,
      messageId: messageId,
      senderId: message.data['senderId']?.toString() ?? '',
      senderName:
          message.data['title']?.toString() ??
          message.notification?.title ??
          'New message',
      text:
          message.data['body']?.toString() ??
          message.notification?.body ??
          'New message',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next != null) unawaited(_syncToken(next));
      if (next == null) _registeredFor = null;
    });
    return widget.child;
  }
}
