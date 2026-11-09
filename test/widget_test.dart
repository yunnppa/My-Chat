import 'dart:typed_data';

import 'package:chat_app/app/app.dart';
import 'package:chat_app/app/theme/theme_mode_controller.dart';
import 'package:chat_app/features/chat/domain/chat_models.dart';
import 'package:chat_app/features/chat/domain/chat_repository.dart';
import 'package:chat_app/features/chat/presentation/chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home shell shows Chats tab content', (tester) async {
    SharedPreferences.setMockInitialValues({
      sessionUserIdKey: 'me',
      sessionNameKey: 'You',
      sessionTokenKey: 'token',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        ],
        child: LiquidGlassWidgets.wrap(
          child: const ChatApp(),
          brightnessResolver: Theme.maybeBrightnessOf,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Alex Rivera'), findsOneWidget);

    final title = find.descendant(
      of: find.byType(GlassAppBar),
      matching: find.text('Chats'),
    );
    final titleBottom = tester.getRect(title).bottom;
    final firstChatTop = tester.getRect(find.text('Alex Rivera')).top;
    expect(firstChatTop, greaterThanOrEqualTo(titleBottom));
  });

  testWidgets('Theme settings can switch to dark mode', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        ],
        child: LiquidGlassWidgets.wrap(
          child: const ChatApp(),
          brightnessResolver: Theme.maybeBrightnessOf,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatApp)),
    );
    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pump();

    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
  });
}

class _FakeChatRepository implements ChatRepository {
  @override
  void dispose() {}

  @override
  Future<ChatSummary> openDirectChat({
    required AppSession session,
    required String otherUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppSession> register({required String displayName, String? token}) {
    throw UnimplementedError();
  }

  @override
  Future<List<ChatPerson>> searchPeople(AppSession session, String query) {
    return Future.value(const []);
  }

  @override
  Future<ChatMessage> sendMessage({
    required AppSession session,
    required String chatId,
    required String otherUserId,
    required String text,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> markRead({required AppSession session, required String chatId}) {
    return Future.value();
  }

  @override
  Future<void> deleteConversation({
    required AppSession session,
    required String chatId,
    required ChatDeleteScope scope,
  }) {
    return Future.value();
  }

  @override
  Future<void> publishEncryptionKey(AppSession session) {
    return Future.value();
  }

  @override
  Future<void> registerPushToken({
    required AppSession session,
    required String token,
  }) {
    return Future.value();
  }

  @override
  Future<void> uploadAvatar({
    required AppSession session,
    required Uint8List bytes,
  }) {
    return Future.value();
  }

  @override
  Future<Uint8List?> downloadAvatar(String userId) {
    return Future.value();
  }

  @override
  Stream<List<StorySummary>> watchStories(AppSession session) async* {
    yield const [];
  }

  @override
  Future<StorySummary> uploadStory({
    required AppSession session,
    required Uint8List bytes,
    required StoryVisibility visibility,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> markStoryViewed({
    required AppSession session,
    required String storyId,
  }) {
    return Future.value();
  }

  @override
  Future<List<ChatPerson>> storyViewers({
    required AppSession session,
    required String storyId,
  }) {
    return Future.value(const []);
  }

  @override
  Future<List<ChatPerson>> listFriends(AppSession session) {
    return Future.value(const []);
  }

  @override
  Future<ChatPerson> addFriend({
    required AppSession session,
    required String username,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StoryVisibility> storyVisibility(AppSession session) {
    return Future.value(StoryVisibility.public);
  }

  @override
  Future<void> setStoryVisibility({
    required AppSession session,
    required StoryVisibility visibility,
  }) {
    return Future.value();
  }

  @override
  Stream<List<ChatSummary>> watchChats(AppSession session) async* {
    yield const [
      ChatSummary(
        id: '1',
        title: 'Alex Rivera',
        otherUserId: 'alex',
        preview: 'See you at 7?',
        lastMessageAt: null,
        unreadCount: 2,
      ),
    ];
  }

  @override
  Stream<IncomingNotice> incomingMessages(AppSession session) {
    return const Stream.empty();
  }

  @override
  Stream<List<ChatMessage>> watchMessages(AppSession session, String chatId) {
    return const Stream.empty();
  }
}
