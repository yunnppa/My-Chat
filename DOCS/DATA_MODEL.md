# Data Model

Use Firestore documents with server timestamps.

## users/{userId}
- id
- username
- displayName
- photoUrl
- bio
- phoneNumberMasked or privacy-safe representation
- email
- isOnline
- lastSeenAt
- createdAt
- updatedAt
- settings
- privacy

Never expose private account information unnecessarily.

## chats/{chatId}
- id
- type: direct | group
- title
- photoUrl
- createdBy
- participantIds
- adminIds
- lastMessageId
- lastMessagePreview
- lastMessageAt
- createdAt
- updatedAt

## chats/{chatId}/members/{userId}
- userId
- role
- joinedAt
- mutedUntil
- lastReadAt

## chats/{chatId}/messages/{messageId}
- id
- senderId
- type: text | image | video | audio | file | location | live_location | gif | system
- text
- replyToMessageId
- attachment
- location
- liveLocation
- durationMs
- thumbnailUrl
- createdAt
- updatedAt
- editedAt
- deletedAt
- reactions
- readBy
- deliveredTo

Do not put unlimited arrays such as full read receipts into one document. Use subcollections when scale requires it.

## stories/{storyId}
- id
- userId
- mediaType
- mediaUrl
- thumbnailUrl
- caption
- createdAt
- expiresAt
- visibility
- viewCount

Story expiry should be enforced server-side.

## stories/{storyId}/views/{userId}
- userId
- viewedAt

## posts/{postId}
- id
- authorId
- text
- media
- visibility
- createdAt
- updatedAt
- likeCount
- commentCount
- shareCount

## posts/{postId}/comments/{commentId}
- id
- authorId
- text
- createdAt
- updatedAt
- likeCount

## reactions
Use a scalable representation such as:
posts/{postId}/reactions/{userId}
and
messages/{messageId}/reactions/{userId}

Fields:
- userId
- type
- createdAt

## notifications/{notificationId}
- recipientId
- actorId
- type
- entityId
- text
- createdAt
- readAt

## reports/{reportId}
- reporterId
- targetType
- targetId
- reason
- createdAt
- status
