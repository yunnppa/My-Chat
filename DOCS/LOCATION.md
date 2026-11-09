# Location and Live Location

## One-time location
When the user taps Location:
1. Explain why location is needed.
2. Request location permission.
3. Get current position.
4. Show preview on map.
5. Let user cancel/send.
6. Send location message.

Never request location permission during app startup unless absolutely required.

## Live location
User chooses:
- 15 minutes
- 1 hour
- 8 hours
- custom duration if implemented

After starting:
- periodically update location
- show active indicator
- show remaining time
- allow Stop sharing

## Realtime design
Do not create a new Firestore document for every GPS sample indefinitely.

Use one active live-location document per share and update it at a controlled interval.

Recommended update interval:
- adaptive, e.g. 5–15 seconds while actively moving
- slower when stationary

Do not use excessive background GPS updates.

## Privacy
- Clearly indicate when live location is active.
- Show exactly who can see it.
- Automatically expire.
- Allow immediate stop.
- Do not retain unnecessary historical location data.

## Permissions
Handle:
- denied
- denied forever
- restricted
- location services disabled

Provide a settings route when the OS requires manual permission changes.
