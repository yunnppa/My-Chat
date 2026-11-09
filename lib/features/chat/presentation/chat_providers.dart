import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_mode_controller.dart';
import '../data/http_chat_repository.dart';
import '../data/message_crypto.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

const sessionUserIdKey = 'session_user_id';
const sessionNameKey = 'session_display_name';
const sessionTokenKey = 'session_token';
const apiBaseKey = 'chat_api_base';

const defaultApiBase = String.fromEnvironment(
  'CHAT_API_BASE',
  defaultValue: 'http://127.0.0.1:8080',
);

final apiBaseProvider = NotifierProvider<ApiBaseController, String>(
  ApiBaseController.new,
);

class ApiBaseController extends Notifier<String> {
  @override
  String build() {
    return ref.watch(sharedPreferencesProvider).getString(apiBaseKey) ??
        defaultApiBase;
  }

  Future<void> setBase(String value) async {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return;
    state = trimmed;
    await ref.read(sharedPreferencesProvider).setString(apiBaseKey, trimmed);
  }
}

final sessionProvider = NotifierProvider<SessionController, AppSession?>(
  SessionController.new,
);

class SessionController extends Notifier<AppSession?> {
  @override
  AppSession? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final id = prefs.getString(sessionUserIdKey);
    final name = prefs.getString(sessionNameKey);
    final token = prefs.getString(sessionTokenKey);
    if (id == null || name == null || token == null) return null;
    return AppSession(userId: id, displayName: name, token: token);
  }

  Future<void> signIn(String displayName) async {
    final session = await ref
        .read(chatRepositoryProvider)
        .register(displayName: displayName, token: state?.token);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(sessionUserIdKey, session.userId);
    await prefs.setString(sessionNameKey, session.displayName);
    await prefs.setString(sessionTokenKey, session.token);
    state = session;
    try {
      await ref.read(chatRepositoryProvider).publishEncryptionKey(session);
    } catch (_) {}
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repository = HttpChatRepository(
    baseUrl: ref.watch(apiBaseProvider),
    crypto: MessageCrypto(ref.watch(sharedPreferencesProvider)),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final encryptionBootstrapProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return;
  try {
    await ref.read(chatRepositoryProvider).publishEncryptionKey(session);
  } catch (_) {}
});

final chatsProvider = StreamProvider<List<ChatSummary>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return Stream.value(const []);
  ref.watch(encryptionBootstrapProvider);
  return ref.watch(chatRepositoryProvider).watchChats(session);
});

/// Hides unread badges for a chat the user has opened, even before the
/// server refresh returns and even when they leave without replying.
final unreadDismissalProvider =
    NotifierProvider<UnreadDismissal, UnreadDismissalState>(
      UnreadDismissal.new,
    );

class UnreadDismissalState {
  const UnreadDismissalState({this.openChatId, this.acknowledged = const {}});

  final String? openChatId;
  final Map<String, int> acknowledged;
}

class UnreadDismissal extends Notifier<UnreadDismissalState> {
  @override
  UnreadDismissalState build() {
    ref.listen(chatsProvider, (_, next) {
      next.whenData(_dropStaleAcknowledgements);
    });
    return const UnreadDismissalState();
  }

  void open(String chatId) {
    // Only hide while the conversation is open. Do not stamp an
    // acknowledgement here — that was clearing badges even when markRead
    // never succeeded on the server.
    state = UnreadDismissalState(
      openChatId: chatId,
      acknowledged: state.acknowledged,
    );
  }

  void close(String chatId) {
    state = UnreadDismissalState(
      openChatId: state.openChatId == chatId ? null : state.openChatId,
      acknowledged: state.acknowledged,
    );
  }

  void acknowledge(String chatId) {
    state = UnreadDismissalState(
      openChatId: state.openChatId,
      acknowledged: _acknowledged(chatId),
    );
  }

  Map<String, int> _acknowledged(String chatId) {
    final current = _serverUnread(chatId);
    final previous = state.acknowledged[chatId] ?? 0;
    return {
      ...state.acknowledged,
      chatId: current > previous ? current : previous,
    };
  }

  int _serverUnread(String chatId) {
    final chats = ref.read(chatsProvider).asData?.value;
    if (chats == null) return state.acknowledged[chatId] ?? 0;
    for (final chat in chats) {
      if (chat.id == chatId) return chat.unreadCount;
    }
    return 0;
  }

  void _dropStaleAcknowledgements(List<ChatSummary> chats) {
    final next = Map<String, int>.of(state.acknowledged);
    var changed = false;
    for (final chat in chats) {
      final acknowledged = next[chat.id];
      if (acknowledged != null && chat.unreadCount < acknowledged) {
        next.remove(chat.id);
        changed = true;
      }
    }
    if (!changed) return;
    state = UnreadDismissalState(
      openChatId: state.openChatId,
      acknowledged: next,
    );
  }
}

int visibleUnread(UnreadDismissalState dismissal, ChatSummary chat) {
  if (chat.id == dismissal.openChatId) return 0;
  final acknowledged = dismissal.acknowledged[chat.id];
  if (acknowledged == null) return chat.unreadCount;
  if (chat.unreadCount < acknowledged) return chat.unreadCount;
  if (chat.unreadCount == acknowledged) return 0;
  return chat.unreadCount - acknowledged;
}

final storiesProvider = StreamProvider<List<StorySummary>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchStories(session);
});

final friendsProvider = FutureProvider<List<ChatPerson>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return const [];
  return ref.watch(chatRepositoryProvider).listFriends(session);
});

final storyPrivacyProvider =
    AsyncNotifierProvider<StoryPrivacyController, StoryVisibility>(
      StoryPrivacyController.new,
    );

class StoryPrivacyController extends AsyncNotifier<StoryVisibility> {
  @override
  Future<StoryVisibility> build() async {
    final session = ref.watch(sessionProvider);
    if (session == null) return StoryVisibility.public;
    return ref.read(chatRepositoryProvider).storyVisibility(session);
  }

  Future<void> setVisibility(StoryVisibility visibility) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    state = AsyncData(visibility);
    await ref
        .read(chatRepositoryProvider)
        .setStoryVisibility(session: session, visibility: visibility);
    ref.invalidate(storiesProvider);
  }
}

final conversationProvider = AsyncNotifierProvider.autoDispose
    .family<ConversationController, List<ChatMessage>, String>(
      ConversationController.new,
    );

class ConversationController extends AsyncNotifier<List<ChatMessage>> {
  ConversationController(this.chatId);

  final String chatId;

  @override
  Future<List<ChatMessage>> build() async {
    final session = ref.watch(sessionProvider);
    if (session == null) return const [];
    final dismissal = ref.read(unreadDismissalProvider.notifier);
    Future.microtask(() {
      if (!ref.mounted) return;
      dismissal.open(chatId);
    });
    ref.onDispose(() => dismissal.close(chatId));
    final repository = ref.watch(chatRepositoryProvider);
    final first = Completer<List<ChatMessage>>();
    final subscription = repository
        .watchMessages(session, chatId)
        .listen(
          (messages) {
            if (!first.isCompleted) {
              first.complete(messages);
            } else {
              state = AsyncData(messages);
            }
            _markRead();
          },
          onError: (Object error, StackTrace stack) {
            if (!first.isCompleted) {
              first.completeError(error, stack);
            } else {
              state = AsyncError(error, stack);
            }
          },
        );
    ref.onDispose(subscription.cancel);
    return first.future;
  }

  Future<void> send(String text) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final otherUserId =
        ref
            .read(chatsProvider)
            .asData
            ?.value
            .where((chat) => chat.id == chatId)
            .map((chat) => chat.otherUserId)
            .firstOrNull ??
        '';
    final message = await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          session: session,
          chatId: chatId,
          otherUserId: otherUserId,
          text: text,
        );
    final current = state.value ?? const <ChatMessage>[];
    if (current.every((item) => item.id != message.id)) {
      state = AsyncData([...current, message]);
    }
  }

  Future<void> _markRead() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final dismissal = ref.read(unreadDismissalProvider.notifier);
    try {
      await ref
          .read(chatRepositoryProvider)
          .markRead(session: session, chatId: chatId);
      dismissal.acknowledge(chatId);
      if (ref.mounted) ref.invalidate(chatsProvider);
    } catch (_) {
      // Opening the chat still hides the badge until a newer message arrives.
    }
  }

  Future<void> deleteConversation(ChatDeleteScope scope) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    await ref
        .read(chatRepositoryProvider)
        .deleteConversation(session: session, chatId: chatId, scope: scope);
    ref.invalidate(chatsProvider);
  }
}
