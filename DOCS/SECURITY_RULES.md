# Security Requirements

## General
Security must be enforced server-side.

Client-side checks are UX only.

## Firestore
Users can:
- read/update their own allowed profile fields
- read chats only when they are members
- create messages only as themselves and only in chats they can access
- edit/delete only messages they are authorized to modify
- create their own posts/stories
- modify/delete only their own content

Admins:
- can manage group membership according to group role

## Storage
Verify:
- authenticated user
- resource ownership
- chat membership
- allowed content type
- allowed file size where supported

## Cloud Functions/backend
Use trusted backend code for:
- notification fan-out
- cleanup
- moderation hooks
- counters where atomic client updates are unsafe
- GIF API key protection
- feed processing if needed

## Abuse prevention
Implement:
- rate limits
- report/block
- message spam controls
- upload size limits
- content moderation hooks
- App Check
- server-side validation

## Privacy
Do not log:
- message content
- private location coordinates
- access tokens
- passwords
- sensitive personal data

Production analytics must avoid unnecessary PII.
