# Authentication and Profile

## Authentication
MVP:
- email/password
- logout
- session restoration
- password reset

Optional:
- phone authentication
- Google/Apple sign-in

## Onboarding
- sign up
- username
- display name
- avatar
- optional bio

## Profile
- avatar
- display name
- username
- bio
- joined date
- shared media
- mutual groups where applicable

## Presence
Track:
- isOnline
- lastSeenAt

Presence should not update Firestore on every UI rebuild.

## Privacy settings
Allow:
- who can message me
- who can see my stories
- who can see my last seen
- who can see my profile photo
- who can add me to groups
- live location permissions

Do not expose presence or private profile fields to unauthorized users.
