# Offline and Sync

## Requirements
The app should remain usable during temporary connectivity loss.

Support:
- cached conversations
- cached profile data
- message drafts
- queued outgoing messages where practical
- upload retry
- optimistic UI

## Message send
Show optimistic state:
pending -> sent -> delivered -> read

If sending fails:
- preserve the message locally
- show retry
- do not silently lose user input

## Conflict handling
For editable content:
- server timestamp is authoritative
- avoid overwriting newer server data with stale local data
- define explicit rules for message edit/delete conflicts

## Network state
Show a lightweight offline indicator when useful, but do not block the whole app because of connectivity loss.
