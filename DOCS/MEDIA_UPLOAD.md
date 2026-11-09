# Media and File Upload Specification

## Storage layout
Use predictable ownership-based paths.

Examples:
users/{userId}/avatars/{fileId}
chats/{chatId}/messages/{messageId}/{fileName}
stories/{userId}/{storyId}/{fileName}
posts/{userId}/{postId}/{fileName}

## Upload process
1. Validate local file.
2. Generate a unique ID.
3. Compress/resize if appropriate.
4. Create an upload state.
5. Upload to Storage.
6. Obtain secure download URL/reference.
7. Write message/post/story metadata.
8. Mark upload complete.

## Requirements
- Show progress.
- Allow retry.
- Avoid duplicate uploads.
- Clean up abandoned uploads.
- Generate thumbnails for video where useful.
- Cache thumbnails and images.
- Lazy-load large media.
- Never store raw binary data in Firestore.

## Limits
Define configurable limits in one place:
- max image size
- max video size
- max video duration
- max audio duration
- max attachment size
- max story size
- max post media count

Do not hard-code these values throughout the UI.

## Security
Storage rules must verify:
- authenticated user
- allowed path ownership
- chat membership for chat media
- author ownership for stories/posts
- content size/type where supported

Use backend processing for stronger content validation.
