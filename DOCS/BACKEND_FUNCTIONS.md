# Backend / Cloud Functions

Recommended server-side functions:

## Notifications
onMessageCreated:
- identify recipients
- respect mute/privacy
- send FCM notification

## Story cleanup
Scheduled job:
- find expired stories
- delete or archive metadata
- delete associated media

## Upload cleanup
Scheduled job:
- identify orphaned uploads
- delete temporary/unreferenced media

## Counters
Maintain post/comment/reaction counts where atomic client-side updates are not sufficient.

## Moderation hooks
Optional:
- detect suspicious uploads
- process reports
- block abusive accounts
- integrate content moderation provider

## Live location
Ensure expired live-location shares are no longer visible even if the client fails to stop sharing.

## Security
Functions must validate:
- authenticated identity
- resource ownership
- membership
- allowed operation
