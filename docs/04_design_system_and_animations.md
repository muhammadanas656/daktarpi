# DaktarPai - Design System and Animations

## 1. Theme Foundation

The current UI system is built on:
- Material 3
- `GoogleFonts.poppinsTextTheme()`
- app-specific tokens under `lib/core/theme/`

`AppTheme` provides:
- light and dark themes
- a `ColorScheme` seeded from `AppColors.primaryGreen`
- shared button and input decoration themes

## 2. Shared Styling Primitives

The most reused styling helpers are in `AppStyles`:
- `pageGradient(context)` for page backgrounds
- `surfaceCard(context)` for bordered cards and panels
- `cardShadow(context)` for standard light-mode elevation
- `elevatedShadow(context)` for dialogs and floating surfaces
- `primaryShadow(context, color)` for emphasized controls
- `drawerShadow(context)` for the drawer transform in `MainWrapper`

These helpers already adapt to light and dark mode, so screens generally compose from them instead of hardcoding colors.

## 3. Input and Control Pattern

`AppTextField` is the shared text-input primitive.

Current capabilities include:
- optional labels
- password visibility toggle
- prefix and suffix widgets
- single-line and multiline layouts
- adaptive fill, border, and text colors

`AuthTextField` and `CustomTextField` delegate to this shared implementation.

The app also uses `PessimisticSwitch` for settings that should update UI state only after async work succeeds.

## 4. Current Motion Patterns

The implemented motion system is concentrated in a few places:

- `MainWrapper`
  Drawer open/close uses translation, scaling, rounded-corner growth, and an optional startup hint animation.
- `OfflineModeGuard`
  Shows and hides an offline banner with `AnimatedPositioned`.
- `SettingsPreferencesSection`
  Uses `AnimatedSize` for expanding notification controls and inline reminder-time controls.
- `Verify2FAScreen`
  Uses `AnimatedSwitcher` and `AnimatedCrossFade` between TOTP and recovery-code modes.
- `NotificationsScreen`
  Uses `Dismissible` for swipe-to-delete notification cards.
- `LiveCountdownBadge`
  Updates once per second for waiting appointments and flashes when close to expiry.

## 5. Practical Layout Rules in the Current Code

Across the app, most screens follow the same layout approach:
- gradient or scaffold-backed page surfaces
- `surfaceCard` containers for major content groups
- bottom action bars for primary actions in booking, records, and settings flows
- `SingleChildScrollView` plus safe-area padding for forms, dialogs, and sheets

This keeps the app visually consistent without a separate design-system package.
