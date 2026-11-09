# Cursor Prompt Templates

## Implement a feature
Read:
- README.md
- PROJECT_SPECS.md
- ARCHITECTURE.md
- the relevant feature specification

Then implement the requested feature end-to-end.

Requirements:
- preserve existing architecture
- create/update domain models
- create repository interface
- implement data source/repository
- add Riverpod state
- build UI
- handle loading/empty/error states
- add tests
- run formatter/analyzer/tests
- report changed files and remaining setup

## Example: text chat
Implement Phase 3 direct messaging.

Start by inspecting the existing project. Do not invent a second architecture.

Implement:
- chat list
- direct chat creation
- realtime message stream
- text message sending
- optimistic sending state
- delivered/read states
- reply
- emoji
- reactions

Use the existing backend configuration. Do not use mock data unless explicitly requested.

## Example: rich media
Implement rich message support according to MESSAGE_TYPES.md and MEDIA_UPLOAD.md.

Include:
- picker
- preview
- validation
- compression where appropriate
- upload progress
- retry
- message creation
- rendering
- tests

## Example: live location
Implement LOCATION.md end-to-end.

Pay special attention to:
- permissions
- expiration
- stop sharing
- privacy
- realtime updates
- battery efficiency
- backend authorization

## Do not
- put Firebase calls in widgets
- hard-code secrets
- bypass security rules
- use unlimited realtime GPS updates
- silently discard failed uploads
- claim unsupported features are implemented
