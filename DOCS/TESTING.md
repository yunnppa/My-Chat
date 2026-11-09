# Testing Strategy

## Unit tests
Test:
- message model serialization
- validators
- theme controller
- location expiry
- message type mapping
- repository business logic
- pagination logic

## Widget tests
Test:
- chat composer
- message bubbles
- upload progress
- story cards
- post cards
- theme switching
- permission error states

## Integration tests
Cover:
1. Sign up/login
2. Create direct chat
3. Send text
4. Send image
5. Send video
6. Record/send voice
7. Send file
8. Send location
9. Start/stop live location
10. Create/view story
11. Create/react/comment on post
12. Change theme
13. Logout/login persistence

## Failure cases
Test:
- no internet
- upload failure
- permission denied
- expired live location
- deleted message
- deleted user
- invalid file
- oversized media
- unauthorized chat access

## Performance
Check:
- scrolling long chats
- large images
- video playback
- feed pagination
- memory usage
- unnecessary widget rebuilds
