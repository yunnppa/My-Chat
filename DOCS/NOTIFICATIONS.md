# Notifications

Use Firebase Cloud Messaging.

Notification types:
- new message
- group message
- mention
- reaction
- comment
- story interaction
- friend/follow event if implemented

## Rules
- Never send a push notification for every typing event.
- Respect mute settings.
- Do not expose private message text in notifications when privacy settings prohibit it.
- Deep link to the correct chat/post/story.
- Handle foreground, background and terminated states.

Notification payload should contain IDs rather than sensitive content whenever possible.
