# ChatApp — Cursor Implementation Specification

## 1. Product vision
Build a modern cross-platform social messaging application combining:
- Telegram-style real-time private/group messaging
- Facebook-style stories and feed
- Rich media sharing
- Location and live-location sharing
- Themes, emojis and GIFs
- File attachments
- Profile, privacy and notification controls

Target platform: Flutter mobile application.

## 2. Implementation order
Cursor should implement in this order:
1. Project foundation and architecture
2. Authentication and user profiles
3. Home/navigation shell
4. One-to-one chat
5. Media/file messages
6. Voice messages
7. Location/live location
8. Groups
9. Stories
10. Feed/posts
11. Reactions/comments
12. Theme customization
13. Notifications
14. Search
15. Privacy/security hardening
16. Testing and release preparation

## 3. Non-negotiable rules
- Use null-safe Dart.
- Keep UI, state management, domain logic, data access and platform services separated.
- Never place Firebase/Supabase/API calls directly inside widgets.
- Use repositories/interfaces so backend implementation can be replaced.
- Use immutable models where practical.
- Handle loading, empty, error, retry and offline states.
- Never expose private credentials or service secrets in the client.
- Validate authorization on the backend/security rules, not only in Flutter.
- Ask for permissions only when a feature needs them.
- Compress/resample media before upload where appropriate.
- Do not upload a full-resolution video/photo when a reasonable optimized version is sufficient.
- All user-generated content must have ownership and authorization checks.

## 4. Definition of done
A feature is complete only when:
- UI is implemented
- State management is implemented
- Repository/data layer is implemented
- Loading/error/empty states exist
- Validation exists
- Authorization/security rules are covered
- Unit/widget/integration tests exist where appropriate
- Accessibility and responsive behavior are considered

## Liquid Glass styling
The app must use `flutter_liquid_glass_widgets` for appropriate navigation chrome and floating
controls. Read `LIQUID_GLASS_STYLE.md` before implementing UI. Check Flutter SDK compatibility
first: package docs currently state Flutter >= 3.41.0. Do not upgrade the toolchain without approval.
