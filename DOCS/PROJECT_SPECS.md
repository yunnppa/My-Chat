# Project Specifications

## App
Name: ChatApp

## Suggested stack
- Flutter
- Dart
- FVM for Flutter version management
- Riverpod for state management
- GoRouter for navigation
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Firebase Cloud Functions
- Firebase App Check
- Google Maps or another licensed map provider for map display
- A GIF provider such as GIPHY/Tenor through a backend proxy
- WebSocket/Firestore realtime listeners for realtime updates

If the project already has an established stack, preserve it instead of replacing it without instruction.

## Suggested dependencies
Use current stable versions compatible with the selected Flutter SDK rather than blindly copying version numbers.

Potential packages:
- flutter_riverpod
- go_router
- firebase_core
- firebase_auth
- cloud_firestore
- firebase_storage
- firebase_messaging
- firebase_app_check
- image_picker
- file_picker
- record
- just_audio
- video_player
- cached_network_image
- emoji_picker_flutter
- geolocator
- permission_handler
- google_maps_flutter
- uuid
- path_provider
- path
- mime
- image
- video_compress or an equivalent maintained package
- share_plus
- connectivity_plus
- freezed/json_serializable if the project chooses generated immutable models

Do not add packages merely because they are listed. Verify compatibility and maintenance first.

## Navigation
Primary tabs:
1. Chats
2. Stories
3. Feed
4. Calls/Activity (optional future module)
5. Profile/Settings

Suggested routes:
- /auth
- /home
- /chat/:chatId
- /new-chat
- /group/:groupId
- /story/:userId
- /create-story
- /feed
- /create-post
- /post/:postId
- /profile/:userId
- /settings
- /settings/theme
- /settings/privacy
- /settings/notifications
- /settings/storage

## Liquid Glass UI requirement
Use `flutter_liquid_glass_widgets` for Liquid Glass surfaces and navigation chrome.
Read `LIQUID_GLASS_STYLE.md` before implementing any UI.

The package documentation currently states Flutter SDK >= 3.41.0 and Dart >= 3.5.0.
Check the project's actual FVM/Flutter version before adding it. If the SDK is too old, do not
silently upgrade or force incompatible dependencies; report the compatibility issue and ask
before changing the project's SDK. Use the package's documented initialization and imports.
