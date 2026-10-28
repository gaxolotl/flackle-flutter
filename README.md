# Flackle Mobile

A native-feeling Flutter client for [Flackle](https://flackle.com), targeting Android and iOS. The same codebase also builds for web and desktop.

This is an unofficial personal client. It is not affiliated with Flackle or Folkward LLC.

## Download

See [Releases](https://github.com/gaxolotl/flackle-flutter/releases) for the universal Android APK and the unsigned iOS IPA.

## Features

- Sign in, MFA/backup-code login, session restore, and secure refresh-token storage.
- Servers, server folders/rail ordering, categories, channels, DMs, and group DMs.
- A combined server rail and channel list on phones, so switching servers and channels does not require leaving the channel browser.
- Role-grouped member lists with hoisted role sections and role icons next to member names.
- Live gateway updates: messages, edits, deletes, reactions, typing, presence, member changes, channels and conversations.
- Mentions and replies with `@` / `#` autocomplete, including mentionable roles.
- Reply pings with a per-reply `@ ON` / `@ OFF` toggle and an on, remember-last or off default in Chat settings.
- Full message history with older-message pagination, link previews, image/attachment embeds, replies, reactions, editing and deleting.
- Reply previews follow later edits to the original message, and Flackle message links jump to the referenced message even when it is outside the loaded page.
- Remove link previews from your own messages for everyone; the removal survives later edits.
- An always-visible formatting bar with bold, italic, underline, strikethrough and an embeds toggle.
- Composer drafts are kept per channel or DM when you leave before sending.
- Media saving to your Flackle saved-media collection.
- GIF picker powered by KLIPY, with trending, search, favourites and custom GIF folders.
- Profile editor for avatar, banner and display name, with profile badges that survive avatar changes.
- Android notifications for mentions, `@everyone`, replies and direct messages, with **Mark as read** and inline **Reply** actions.
- Android foreground service keeps the gateway connected while the app is closed or in the background.
- Notification history is persisted and restored in the You tab.
- Light/dark themes, accent colours, density and text-size preferences, plus a custom typing indicator (text and up to three emojis).

## Requirements

- Flutter **3.47.8** or newer (Dart 3.13+).
- Android SDK 36, JDK 17+.
- iOS builds require macOS, Xcode and CocoaPods (iOS 15+).
- For web development, the optional same-origin proxy in `scripts/real-proxy.mjs`.

## Run

```sh
flutter pub get
flutter analyze
flutter run
```

### Android

```sh
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The build uses the debug signing key unless `android/key.properties` is provided.

### Web (development proxy)

```sh
flutter build web --release \
  --dart-define=FLACKLE_BASE_URL=http://127.0.0.1:8787 \
  --dart-define=FLACKLE_MEDIA_PROXY=/media?url=
node scripts/real-proxy.mjs
```

### iOS

On macOS:

```sh
flutter build ios --release --no-codesign
```

A signed IPA requires an Apple Developer certificate and provisioning profile. Unsigned builds can be packaged for inspection or sideloading with your own signing tooling.

## Notifications

Android 13+ requires notification permission. The app requests it on first launch. Real-time notifications while the app is closed are provided by a foreground service and therefore show a low-priority "Flackle is listening" notification. If Android force-stops the app or the OEM kills the service, the gateway cannot receive messages; guaranteed delivery in that state would require server-side push (FCM), which Flackle does not expose publicly.

## Project layout

```text
lib/
  core/        API client, gateway, models, state, preferences, notifications
  screens/     Login, workspace, chat, settings, profile, channel and DM UI
  ui/          Shared widgets, icons, emoji and theme helpers
android/       Android host project
ios/           iOS host project
web/           Web host project
scripts/       Development proxy and asset helpers
```

## Security and privacy

- Credentials are entered directly into Flackle's API and are never sent anywhere else by this app.
- Session tokens are stored with `flutter_secure_storage` where available, with a SharedPreferences fallback for platforms without a keyring.
- Never use another person's credentials or perform account actions without their permission.

## Disclaimer

Flackle, its name, branding, and services belong to Folkward LLC. This project is an independent client and is not endorsed by or affiliated with Flackle.
