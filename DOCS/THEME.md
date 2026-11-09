# Theme System

## Themes
Provide:
- System default
- Light
- Dark
- Custom accent color

Persist user preference locally and optionally sync to user profile.

## Architecture
Create:
- AppTheme
- ThemeMode controller/provider
- light ThemeData
- dark ThemeData
- color scheme
- typography
- component themes

Avoid hard-coded colors in widgets.

Use semantic theme colors such as:
- surface
- primary
- onPrimary
- error
- outline
- messageIncoming
- messageOutgoing

## Accessibility
- respect system text scaling
- maintain readable contrast
- provide visible focus states
- do not communicate status through color alone

## Liquid Glass integration
Use `flutter_liquid_glass_widgets` according to `LIQUID_GLASS_STYLE.md`.
Keep theme colors, text styles and contrast accessible in both light and dark modes.
Reserve glass mainly for floating navigation and transient controls, not all content.
