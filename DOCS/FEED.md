# Feed

## Post types
- text
- image
- multiple images
- video
- link preview (future)

## Feed card
Show:
- author
- avatar
- timestamp
- visibility
- content
- media
- reaction count
- comment count
- share count
- action menu

## Actions
- react
- comment
- share
- save (future)
- report
- hide
- delete own post
- edit own post

## Feed loading
Use cursor-based pagination.

Never load the entire feed at once.

Recommended:
- first page: 10–20 posts
- load next page near the end
- pull to refresh
- retry on failure

## Feed ranking
MVP chronological feed is preferred.
Future ranking can consider:
- relationship
- engagement
- recency
- content affinity

Do not implement a complex ranking algorithm before the basic feed is stable.
