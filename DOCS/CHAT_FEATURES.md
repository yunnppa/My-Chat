# Chat Feature Specification

## Direct chat
Users can:
- start a chat
- send text
- send emoji
- send GIF
- send image
- send video
- send voice
- send file
- send location
- send live location
- reply
- react
- edit own messages
- delete own messages
- copy text
- forward message (future)
- search chat (future)

## Composer
Components:
- attachment button
- text field
- emoji button
- GIF button
- microphone button
- send button

Behavior:
- Send button appears when text exists.
- Microphone appears when composer is empty.
- Attachment picker opens a bottom sheet.
- Show upload progress.
- Preserve drafts locally.

## Message bubble
Display:
- sender avatar where appropriate
- content
- timestamp
- delivery/read state for own messages
- reactions
- reply preview
- edited indicator
- deleted indicator

## Reply
Long press/swipe a message -> Reply.
Composer shows reply preview.
Persist replyToMessageId.

## Reactions
Use configurable emoji reactions.
Tapping an existing reaction toggles the user's reaction.

## Group chat
Support:
- group name/photo
- members
- admins
- add/remove members
- leave group
- mute
- admin-only settings

Authorization must be enforced server-side.
