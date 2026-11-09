import 'dart:typed_data';

import 'chat_models.dart';

abstract class ChatRepository {
  Future<AppSession> register({required String displayName, String? token});

  Stream<List<ChatSummary>> watchChats(AppSession session);

  Stream<List<ChatMessage>> watchMessages(AppSession session, String chatId);

  Stream<IncomingNotice> incomingMessages(AppSession session);

  Future<List<ChatPerson>> searchPeople(AppSession session, String query);

  Future<ChatSummary> openDirectChat({
    required AppSession session,
    required String otherUserId,
  });

  Future<ChatMessage> sendMessage({
    required AppSession session,
    required String chatId,
    required String otherUserId,
    required String text,
  });

  Future<void> markRead({required AppSession session, required String chatId});

  Future<void> deleteConversation({
    required AppSession session,
    required String chatId,
    required ChatDeleteScope scope,
  });

  Future<void> publishEncryptionKey(AppSession session);

  Future<void> registerPushToken({
    required AppSession session,
    required String token,
  });

  Future<void> uploadAvatar({
    required AppSession session,
    required Uint8List bytes,
  });

  Future<Uint8List?> downloadAvatar(String userId);

  Stream<List<StorySummary>> watchStories(AppSession session);

  Future<StorySummary> uploadStory({
    required AppSession session,
    required Uint8List bytes,
    required StoryVisibility visibility,
  });

  Future<void> markStoryViewed({
    required AppSession session,
    required String storyId,
  });

  Future<List<ChatPerson>> storyViewers({
    required AppSession session,
    required String storyId,
  });

  Future<List<ChatPerson>> listFriends(AppSession session);

  Future<ChatPerson> addFriend({
    required AppSession session,
    required String username,
  });

  Future<StoryVisibility> storyVisibility(AppSession session);

  Future<void> setStoryVisibility({
    required AppSession session,
    required StoryVisibility visibility,
  });

  void dispose();
}
