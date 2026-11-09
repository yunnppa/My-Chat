import 'package:chat_app/features/chat/domain/chat_models.dart';
import 'package:chat_app/features/chat/presentation/chat_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const chat = ChatSummary(
    id: 'chat_1',
    title: 'Sam',
    otherUserId: 'sam',
    preview: 'Hello',
    lastMessageAt: null,
    unreadCount: 3,
  );

  test('opening a chat hides the badge only while it is open', () {
    const closed = UnreadDismissalState();
    expect(visibleUnread(closed, chat), 3);

    const open = UnreadDismissalState(openChatId: 'chat_1');
    expect(visibleUnread(open, chat), 0);

    const left = UnreadDismissalState();
    expect(visibleUnread(left, chat), 3);
  });

  test('acknowledge clears the badge until a newer unread arrives', () {
    const dismissed = UnreadDismissalState(acknowledged: {'chat_1': 3});
    expect(visibleUnread(dismissed, chat), 0);

    const newer = ChatSummary(
      id: 'chat_1',
      title: 'Sam',
      otherUserId: 'sam',
      preview: 'Again',
      lastMessageAt: null,
      unreadCount: 4,
    );
    expect(visibleUnread(dismissed, newer), 1);
  });
}
