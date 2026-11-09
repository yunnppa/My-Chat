import 'package:flutter_test/flutter_test.dart';

import '../tool/chat_hub.dart';

void main() {
  test('two users can exchange a message', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');

    final chat = hub.openDirect(token: alex.token, otherUserId: sam.id);
    hub.send(token: alex.token, chatId: chat.id, text: 'See you at 7?');
    final reply = hub.send(
      token: sam.token,
      chatId: chat.id,
      text: 'On my way',
    );

    final alexMessages = hub.messages(token: alex.token, chatId: chat.id);
    final samChats = hub.chatsFor(sam.token);

    expect(alexMessages.map((message) => message.text), [
      'See you at 7?',
      'On my way',
    ]);
    expect(reply.senderId, sam.id);
    expect(samChats.single.title, 'Alex');
    expect(samChats.single.preview, 'On my way');
    expect(samChats.single.unreadCount, 1);
    expect(hub.chatsFor(alex.token).single.unreadCount, 1);

    hub.markRead(token: sam.token, chatId: chat.id);
    expect(hub.chatsFor(sam.token).single.unreadCount, 0);

    hub.send(token: alex.token, chatId: chat.id, text: 'Bring the tickets');
    expect(hub.chatsFor(sam.token).single.unreadCount, 1);
    expect(hub.searchUsers(token: alex.token).single.displayName, 'Sam');

    hub.send(token: alex.token, chatId: chat.id, text: 'e2e1.hidden');
    expect(hub.chatsFor(sam.token).single.preview, 'Encrypted message');

    hub.deleteChat(token: sam.token, chatId: chat.id, scope: 'both');
    expect(hub.chatsFor(alex.token), isEmpty);
    expect(hub.chatsFor(sam.token), isEmpty);
    expect(
      () => hub.messages(token: alex.token, chatId: chat.id),
      throwsA(isA<HubException>()),
    );
  });

  test('delete for you hides the chat only for that person', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');
    final chat = hub.openDirect(token: alex.token, otherUserId: sam.id);
    hub.send(token: alex.token, chatId: chat.id, text: 'Hi');

    hub.deleteChat(token: sam.token, chatId: chat.id, scope: 'me');
    expect(hub.chatsFor(sam.token), isEmpty);
    expect(hub.chatsFor(alex.token).single.id, chat.id);
    expect(hub.messages(token: alex.token, chatId: chat.id), hasLength(1));

    hub.send(token: alex.token, chatId: chat.id, text: 'Again');
    expect(hub.chatsFor(sam.token).single.preview, 'Again');
  });

  test('users can publish encryption public keys', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    hub.setPublicKey(token: alex.token, publicKey: 'abc123');
    expect(hub.publicKeyOf(alex.id), 'abc123');
    final restored = ChatHub()..load(hub.toJson());
    expect(restored.publicKeyOf(alex.id), 'abc123');
  });

  test('usernames are unique', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    hub.register(displayName: 'Sam');

    expect(
      () => hub.register(displayName: 'alex'),
      throwsA(
        isA<HubException>().having(
          (error) => error.message,
          'message',
          'this username is taken',
        ),
      ),
    );
    expect(
      () => hub.register(token: alex.token, displayName: '  Sam  '),
      throwsA(
        isA<HubException>().having(
          (error) => error.message,
          'message',
          'this username is taken',
        ),
      ),
    );

    final renamed = hub.register(token: alex.token, displayName: 'Alex Rivera');
    expect(renamed.id, alex.id);
    expect(renamed.displayName, 'Alex Rivera');
    expect(
      hub.register(token: alex.token, displayName: 'alex rivera').displayName,
      'alex rivera',
    );
  });

  test('profile photos are stored for that user', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');
    final chat = hub.openDirect(token: alex.token, otherUserId: sam.id);

    expect(hub.avatarOf(alex.id), isNull);
    expect(hub.chatsFor(sam.token).single.avatarRevision, 0);

    final revision = hub.setAvatar(token: alex.token, bytes: [1, 2, 3, 4]);
    expect(revision, 1);
    expect(hub.avatarOf(alex.id), [1, 2, 3, 4]);
    expect(hub.chatsFor(sam.token).single.avatarRevision, 1);

    final restored = ChatHub()..load(hub.toJson());
    expect(restored.avatarOf(alex.id), [1, 2, 3, 4]);
    expect(restored.chatsFor(sam.token).single.id, chat.id);

    expect(
      () => hub.setAvatar(token: alex.token, bytes: const []),
      throwsA(isA<HubException>()),
    );
  });

  test('stories are shared and expire after a day', () {
    var clock = DateTime.utc(2026, 1, 1, 12);
    final hub = ChatHub(now: () => clock);
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');

    final story = hub.addStory(token: alex.token, bytes: [9, 8, 7]);
    clock = clock.add(const Duration(seconds: 1));
    final newer = hub.addStory(token: alex.token, bytes: [6, 5, 4]);
    expect(story.displayName, 'Alex');
    expect(hub.storiesFor(sam.token).map((item) => item.id), [
      newer.id,
      story.id,
    ]);
    expect(hub.storyImage(token: sam.token, storyId: story.id), [9, 8, 7]);

    final restored = ChatHub(now: () => clock)..load(hub.toJson());
    expect(restored.storiesFor(sam.token).map((item) => item.id), [
      newer.id,
      story.id,
    ]);
    expect(restored.storyImage(token: sam.token, storyId: newer.id), [6, 5, 4]);

    clock = clock.add(const Duration(hours: 25));
    expect(hub.storiesFor(sam.token), isEmpty);
    expect(hub.storyImage(token: sam.token, storyId: story.id), isNull);
  });

  test('friends and story privacy control who can view a story', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');
    final jordan = hub.register(displayName: 'Jordan');
    final story = hub.addStory(token: alex.token, bytes: [1, 2, 3]);

    expect(hub.storiesFor(sam.token).single.id, story.id);
    expect(hub.addFriend(token: alex.token, username: 'sam').id, sam.id);
    expect(
      () => hub.addFriend(token: alex.token, username: 'Sam'),
      throwsA(
        isA<HubException>().having(
          (error) => error.message,
          'message',
          'Already friends',
        ),
      ),
    );
    expect(
      () => hub.addFriend(token: alex.token, username: 'Alex'),
      throwsA(isA<HubException>()),
    );

    hub.setStoryVisibility(token: alex.token, visibility: 'friends');
    expect(hub.storiesFor(sam.token).single.id, story.id);
    expect(hub.storiesFor(jordan.token), isEmpty);
    expect(hub.storiesFor(alex.token).single.id, story.id);
    expect(hub.storyImage(token: jordan.token, storyId: story.id), isNull);

    hub.setStoryVisibility(token: alex.token, visibility: 'onlyMe');
    expect(hub.storiesFor(sam.token), isEmpty);
    expect(hub.storiesFor(alex.token).single.id, story.id);

    final restored = ChatHub()..load(hub.toJson());
    expect(restored.friendsFor(alex.token).single.displayName, 'Sam');
    expect(restored.storyVisibilityFor(alex.token), 'onlyMe');
  });

  test('a story keeps the privacy chosen when it was uploaded', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');
    final hidden = hub.addStory(
      token: alex.token,
      bytes: [1],
      visibility: 'onlyMe',
    );

    expect(hub.storiesFor(sam.token), isEmpty);
    expect(hub.storiesFor(alex.token).single.id, hidden.id);
    expect(hub.storyImage(token: sam.token, storyId: hidden.id), isNull);

    hub.setStoryVisibility(token: alex.token, visibility: 'public');
    expect(hub.storiesFor(sam.token), isEmpty);

    final open = hub.addStory(
      token: alex.token,
      bytes: [2],
      visibility: 'public',
    );
    expect(hub.storiesFor(sam.token).single.id, open.id);

    final restored = ChatHub()..load(hub.toJson());
    expect(restored.storiesFor(sam.token).single.id, open.id);
    expect(restored.storiesFor(alex.token), hasLength(2));
  });

  test('story viewers are the people who opened the story', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');
    final jordan = hub.register(displayName: 'Jordan');
    final story = hub.addStory(token: alex.token, bytes: [4]);

    hub.recordStoryView(token: alex.token, storyId: story.id);
    hub.recordStoryView(token: sam.token, storyId: story.id);
    expect(hub.storiesFor(sam.token).single.seen, isTrue);
    expect(hub.storiesFor(alex.token).single.seen, isTrue);
    expect(hub.storiesFor(jordan.token).single.seen, isFalse);
    hub.storyImage(token: jordan.token, storyId: story.id);
    hub.recordStoryView(token: sam.token, storyId: story.id);

    expect(
      hub
          .storyViewers(token: alex.token, storyId: story.id)
          .map((user) => user.displayName),
      ['Sam', 'Jordan'],
    );
    expect(
      () => hub.storyViewers(token: sam.token, storyId: story.id),
      throwsA(
        isA<HubException>().having((error) => error.status, 'status', 403),
      ),
    );

    final restored = ChatHub()..load(hub.toJson());
    expect(
      restored
          .storyViewers(token: alex.token, storyId: story.id)
          .map((user) => user.displayName),
      ['Sam', 'Jordan'],
    );
    expect(restored.storiesFor(sam.token).single.seen, isTrue);
    expect(restored.storiesFor(jordan.token).single.seen, isTrue);
  });

  test('push tokens are stored and returned for message recipients', () {
    final hub = ChatHub();
    final alex = hub.register(displayName: 'Alex');
    final sam = hub.register(displayName: 'Sam');
    hub.registerPushToken(token: sam.token, fcmToken: 'sam-device');
    final chat = hub.openDirect(token: alex.token, otherUserId: sam.id);
    final message = hub.send(token: alex.token, chatId: chat.id, text: 'Ping');

    final notice = hub.pushNoticeForMessage(
      senderId: alex.id,
      message: message,
    );
    expect(notice, isNotNull);
    expect(notice!.tokens, {'sam-device'});
    expect(notice.title, 'Alex');
    expect(notice.body, 'Ping');
    expect(notice.chatId, chat.id);

    final restored = ChatHub()..load(hub.toJson());
    expect(restored.pushTokensFor(sam.id), {'sam-device'});
  });
}
