# Liquid Glass UI Style Guide — ChatApp

## Goal
Give ChatApp a premium, modern Liquid Glass appearance inspired by layered glass interfaces,
while keeping chat content, stories and feed content easy to read.

Required package: `flutter_liquid_glass_widgets`
Pub.dev: https://pub.dev/packages/flutter_liquid_glass_widgets
API docs: https://pub.dev/documentation/flutter_liquid_glass_widgets/latest/

## Compatibility gate — do this first
The package documentation currently states Flutter >= 3.41.0 and Dart >= 3.5.0.
Before adding the dependency:
1. Inspect `fvm_config.json`, `.fvmrc`, `pubspec.yaml` and `fvm flutter --version`.
2. Check the exact installed package version and API.
3. If the project's Flutter SDK is below the minimum, stop and report the mismatch.
4. Do not silently upgrade Flutter, FVM, Dart, Gradle or Android Gradle Plugin.
5. Ask for approval before a toolchain upgrade; otherwise do not add an incompatible dependency.

## Dependency
After compatibility is confirmed, add the version currently supported by pub.dev and the project.
The package page currently lists:

```yaml
dependencies:
  flutter_liquid_glass_widgets: ^0.0.1
```

Do not assume this version will remain current; verify it before installing.

## Initialization
Follow the installed version's official docs. The currently documented startup pattern is:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const ChatApp()));
}
```

Documented import:

```dart
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';
```

Verify exact symbols and signatures against the installed version before coding.

## Visual direction
- Backgrounds: restrained gradients with deep navy/indigo in dark mode and soft blue/lavender
  in light mode. Keep backgrounds subtle so text and media remain primary.
- Glass: translucent, softly reflective floating surfaces with rounded corners and restrained
  highlights. Avoid making every widget transparent.
- Accent: one consistent primary accent, such as blue-violet or aqua.
- Typography: clear medium-weight titles, comfortable body text, readable timestamps/metadata.
- Shape: consistent rounded corners and spacing; avoid stacking too many nested surfaces.
- Motion: use package motion sparingly and respect reduced-motion accessibility.
- Contrast: text and icons must remain legible over changing backgrounds and media.

## Where to use glass
Use supported package widgets for navigation chrome and transient controls:
- Main shell: `GlassScaffold`
- Top navigation: `GlassAppBar`
- Bottom navigation: `GlassTabBar` or the documented matching bottom-bar widget
- Floating controls: `GlassButton`, `GlassIconButton`, `GlassChip`
- Search: `GlassSearchBar`
- Menus/dialogs/sheets: documented glass menu, dialog and modal-sheet widgets

Confirm names and APIs against the installed package version.

## Where NOT to use glass
Keep these content surfaces mostly opaque:
- chat message history and message bubbles
- feed posts and comment text
- story media itself
- large photos and videos
- long forms and settings content

Do not nest interactive glass widgets inside `GlassCard` or `GlassContainer`; package documentation
warns that this composition can degrade the effect.

## Screen-specific direction

### Chats
Use a glass app bar with title, search and profile actions. Keep chat rows readable and do not
wrap each row in a glass card. Use subtle unread badges and online indicators.

### Conversation
Use a glass app bar for back, avatar/name and actions. Keep incoming/outgoing bubbles distinct
and readable. The composer may use supported floating glass controls, but test keyboard insets,
safe areas, scrolling and send behavior. Do not place a glass layer over every bubble.

### Stories
Story rings may use the accent palette. Keep story media full-screen and unfiltered. Use restrained
glass overlays only for controls where text contrast remains sufficient.

### Feed
Keep post text and media on solid, theme-aware surfaces. Use glass for top navigation, filter
controls and temporary action sheets, not every feed item.

### Location sharing
A glass bottom sheet or toolbar may host actions. Keep map labels, address/place names and live
location status legible. Make “Stop sharing” explicit and easy to reach.

### Theme settings
Offer System, Light and Dark modes and persist selection. Ensure glass and normal content adapt to
the same brightness setting. Do not offer a glass on/off toggle unless implemented and tested.

## Accessibility and performance
- Respect system text scaling and screen readers.
- Add semantic labels for icon-only controls.
- Ensure sufficient contrast in light and dark modes.
- Respect reduced motion/transparency behavior provided by the package.
- Avoid shader-heavy effects in scrolling lists.
- Test on a lower/mid-range Android device and an iOS device when available.
- Verify keyboard, safe areas, orientation, navigation transitions and screen-reader behavior.
- Add a fallback only if supported by the package's documented architecture; do not invent an API.

## Cursor implementation checklist
- [ ] Confirm Flutter SDK compatibility before dependency installation.
- [ ] Add package and run `flutter pub get`.
- [ ] Initialize package once at startup.
- [ ] Apply `GlassScaffold` to the main shell where appropriate.
- [ ] Add glass app bar and bottom navigation using documented APIs.
- [ ] Keep content lists/posts/messages readable and mostly opaque.
- [ ] Verify APIs against the actual installed package version.
- [ ] Run formatter, analyzer, tests and manual visual checks.
- [ ] Report SDK/package version, files changed, tests run and remaining issues.
