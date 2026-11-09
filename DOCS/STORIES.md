# Stories

## Story creation
User can:
- capture photo
- select photo
- capture video
- select video
- add caption/text
- optionally add emoji/stickers in future
- choose visibility
- publish

## Story viewer
- full-screen media
- progress indicators
- tap left/right navigation
- swipe/close
- pause while holding
- mark viewed
- next user's story

## Expiry
Default story lifetime: 24 hours.

Use server timestamps and backend cleanup/queries.

## Privacy
Visibility:
- everyone/followers/friends depending on product model
- selected users
- hidden from selected users

## Views
Record each viewer once per story unless analytics requirements say otherwise.

## Storage cleanup
Expired story media must be deleted or archived according to retention policy.
