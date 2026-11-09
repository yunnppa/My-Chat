class AppSession {
  const AppSession({
    required this.userId,
    required this.displayName,
    required this.token,
  });

  final String userId;
  final String displayName;
  final String token;
}

class ChatPerson {
  const ChatPerson({
    required this.id,
    required this.displayName,
    this.avatarRevision = 0,
  });

  final String id;
  final String displayName;
  final int avatarRevision;
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    required this.otherUserId,
    required this.preview,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.avatarRevision = 0,
  });

  final String id;
  final String title;
  final String otherUserId;
  final String preview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final int avatarRevision;
}

enum ChatDeleteScope {
  forMe,
  forBoth;

  String get wire {
    return switch (this) {
      ChatDeleteScope.forMe => 'me',
      ChatDeleteScope.forBoth => 'both',
    };
  }
}

class IncomingNotice {
  const IncomingNotice({
    required this.chatId,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.text,
  });

  final String chatId;
  final String messageId;
  final String senderId;
  final String senderName;
  final String text;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;
}

class StorySummary {
  const StorySummary({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.createdAt,
    this.avatarRevision = 0,
    this.seen = false,
  });

  final String id;
  final String userId;
  final String displayName;
  final DateTime createdAt;
  final int avatarRevision;
  final bool seen;
}

enum StoryVisibility {
  public,
  friends,
  onlyMe;

  static StoryVisibility parse(String? raw) {
    return switch (raw) {
      'friends' => StoryVisibility.friends,
      'onlyMe' => StoryVisibility.onlyMe,
      _ => StoryVisibility.public,
    };
  }

  String get wire {
    return switch (this) {
      StoryVisibility.public => 'public',
      StoryVisibility.friends => 'friends',
      StoryVisibility.onlyMe => 'onlyMe',
    };
  }

  String get label {
    return switch (this) {
      StoryVisibility.public => 'Public',
      StoryVisibility.friends => 'Friends only',
      StoryVisibility.onlyMe => 'Only me',
    };
  }

  String get detail {
    return switch (this) {
      StoryVisibility.public => 'Anyone signed in can view this story.',
      StoryVisibility.friends => 'Only friends you added can view this story.',
      StoryVisibility.onlyMe => 'Only you can view this story.',
    };
  }
}
