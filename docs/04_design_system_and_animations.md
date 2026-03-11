# DaktarPai - Design System and Animations

## 1. Theme Foundation

The app uses a lightweight in-repo design system rather than a separate package.

Core foundations:

- Material 3
- `GoogleFonts.poppinsTextTheme()`
- token files under `lib/core/theme/`

Current theme tokens include:

- `AppColors`
  Brand green, light neutrals, destructive red, and the dark "Deep Medical Slate" palette
- `AppTextStyles`
  Heading, body, button, and label presets
- `AppDimens`
  Shared spacing and elevation values
- `AppShapes`
  Shared radii
- `AppMotion`
  Shared durations and curves
- `AppStyles`
  Context-aware gradients, card surfaces, and shadow helpers

`AppTheme` defines both light and dark themes and seeds the `ColorScheme` from `AppColors.primaryGreen`.

## 2. Reusable Surface and Layout Primitives

The most reused styling helpers are in `AppStyles`.

- `pageGradient(context)`
  The default page background. In light mode it uses a white/green wash; in dark mode it collapses to a deep slate gradient.
- `surfaceCard(context)`
  The primary card/panel container with adaptive border and shadow treatment.
- `cardShadow(context)` and `elevatedShadow(context)`
  Standard depth helpers. Shadows are intentionally reduced or removed in dark mode.
- `primaryShadow(context, color)`
  Used for high-emphasis buttons, chips, and branded cards.
- `drawerShadow(context)`
  Used exclusively by the animated drawer shell.

Common layout patterns across the codebase:

- gradient-backed screens with transparent or low-elevation app bars
- large rounded cards for grouped content
- safe-area aware `SingleChildScrollView` forms
- persistent bottom action bars for booking, records, and checkout flows

## 3. Shared Controls

The app has a small but consistent set of reusable controls.

- `AppTextField`
  Shared input primitive with labels, password toggles, prefixes/suffixes, multiline support, and adaptive light/dark colors
- `PrimaryButton`
  Default full-width CTA button
- `SocialButton`
  Branded auth/provider entry button
- `CustomSearchBar`
  Search-field wrapper used in doctor discovery surfaces
- `PessimisticSwitch`
  Settings switch that only commits visual state after the async operation succeeds
- `AppNetworkImage`
  Shared network-image widget used to make profile, doctor, and record media more offline-friendly

Legacy wrappers such as `AuthTextField` and `CustomTextField` still exist, but they delegate back to the shared input approach.

## 4. Visual Character

The current visual system leans toward:

- bright green accenting on light surfaces
- deep slate surfaces in dark mode
- rounded corners almost everywhere
- large, legible Poppins typography
- soft gradients and glass-like dialog treatments for security and settings flows

Many newer screens use `AppStyles.surfaceCard()` and context-aware theme extensions consistently. Some older or one-off surfaces still hardcode white cards or direct colors, so the system is practical rather than fully uniform.

## 5. Motion Patterns in the Current App

Motion is used selectively and mostly for state transitions, not decoration.

- `MainWrapper`
  The drawer animates with translation, scaling, corner-radius growth, and an optional startup hint.
- `OfflineModeGuard`
  Slides the offline banner in and out with `AnimatedPositioned`.
- `InactivityLockGuard`
  Fades the lock overlay with `AnimatedOpacity`.
- `SettingsPreferencesSection`
  Uses `AnimatedSize` to expand notification controls and reminder-time choices.
- `Verify2FAScreen`
  Uses `AnimatedSwitcher`, `AnimatedCrossFade`, and timed recovery-assist reveal.
- `NotificationsScreen`
  Uses `Dismissible` for swipe-to-delete inbox items.
- `ClinicLocationMapSection`
  Uses `AnimatedContainer`, `AnimatedSize`, and `AnimatedRotation` for its in-app map controls.
- `MyAppointmentsScreen`
  Uses dialog transitions, animated receipt generation flows, and an action-required carousel.
- `LiveCountdownBadge`
  Updates every second for waiting appointments and visually escalates near expiry.

## 6. Practical Design Rules to Preserve

When extending the current app, the existing codebase favors these conventions:

- Use theme extensions like `context.colorTextDark` and `context.colorBorder` instead of hardcoded colors
- Prefer `AppStyles.surfaceCard()` over custom card decorations
- Keep primary CTAs full width and visually dominant
- Use `AppMotion` durations for state transitions when adding new motion
- Keep dark-mode behavior intentional; avoid light-mode shadows copied directly into dark surfaces

That is the effective design system today, even though it is implemented as shared helpers inside the app rather than a formal component library.
