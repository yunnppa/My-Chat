# Cursor Rules for ChatApp

You are implementing a production-oriented Flutter application.

## Before coding
- Inspect the existing project.
- Do not overwrite existing working architecture without a reason.
- Identify Flutter/Dart versions and existing dependencies.
- Reuse existing components where appropriate.
- If a required package is incompatible, choose a maintained compatible alternative.

## Coding rules
- Use null safety.
- Follow Dart/Flutter conventions.
- Keep files focused.
- Avoid giant widgets/classes.
- Prefer composition.
- Use Riverpod consistently.
- Use repository interfaces between UI/domain and backend.
- Use typed models.
- Avoid dynamic unless unavoidable.
- Never put secrets in source code.
- Never hard-code backend collection names in widgets.
- Never put business logic inside build().
- Avoid duplicate code.
- Add comments only where they explain non-obvious decisions.

## UI rules
Every async screen must handle:
- loading
- success
- empty
- error

Interactive controls must provide:
- disabled state when necessary
- progress state for uploads/actions
- retry for recoverable failures

## Media rules
- Validate files.
- Compress when appropriate.
- Show upload progress.
- Support retry.
- Clean up temporary files.
- Cache remote media.
- Avoid loading full-size media unnecessarily.

## Permissions
Request permissions just-in-time.
Explain permission purpose before asking where appropriate.
Handle permanently denied permissions.

## Backend
- Repository methods must be typed.
- Convert backend exceptions into app-specific failures.
- Do not leak backend implementation details into UI.

## Security
Assume the client is untrusted.
Every authorization decision must be enforced by Firebase security rules/backend.

## Completion protocol
After implementing a feature:
1. Run formatter.
2. Run analyzer.
3. Run tests.
4. Fix warnings/errors.
5. Summarize changed files.
6. Mention any manual setup still required.

Do not claim a feature is complete if it is only mocked.

## Liquid Glass styling rules
- Read `LIQUID_GLASS_STYLE.md` before building or restyling screens.
- Use `flutter_liquid_glass_widgets` for floating navigation chrome, app bars, tab bars, sheets,
  menus and supported interactive controls.
- Do not wrap ordinary content lists, post cards, message history or every message bubble in glass.
- Do not nest interactive glass controls inside `GlassCard` or `GlassContainer`; follow package docs.
- Initialize the package once at app startup as documented by the installed version.
- Verify the exact package API from installed docs; do not invent constructor parameters or use APIs
  from a different similarly named package.
- Respect reduced-motion/reduced-transparency accessibility behavior.
- Test shader rendering, scrolling, keyboard/IME, navigation and low-end Android performance.
- If Flutter SDK is below the package minimum, stop and report the blocker rather than upgrading it.
