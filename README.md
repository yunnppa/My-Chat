# My-Chat

Flutter chat app (ChatApp) with Liquid Glass UI, local chat hub, E2E message encryption, stories, and Firebase Cloud Messaging push.

## Run

```bash
fvm flutter pub get
fvm dart run tool/chat_server.dart
fvm flutter run
```

Use your machine’s LAN URL in **Settings** when testing on a phone.

## Firebase push

Keep `google-services.json` and `GoogleService-Info.plist` local (they are gitignored). Fill `lib/firebase_options.dart` if needed, then start the server with `FCM_SERVER_KEY` set.
