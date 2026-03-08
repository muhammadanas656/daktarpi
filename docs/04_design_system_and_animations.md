# DaktarPai - Design System and Animations

## 1. Design System Foundation

Design tokens are centralized in `lib/core/theme/`:
- `app_colors.dart`
- `app_text_styles.dart`
- `app_dimens.dart`
- `app_shapes.dart`
- `app_motion.dart`
- `app_styles.dart`

Shared UI components are in `lib/presentation/widgets/`.

## 2. Theming and Visual Direction

Current visual system uses dynamic light/dark theming with context-based color accessors (for example `context.colorTextDark`, `context.colorBorder`).

Core style traits:
- green brand emphasis (`AppColors.primaryGreen`),
- surface-card composition via `AppStyles.surfaceCard(...)`,
- context-aware typography via `AppTextStyles`.

## 3. Input System Standardization

Input architecture is standardized on `AppTextField` (`lib/presentation/widgets/app_text_field.dart`).

Current implementation characteristics:
- consistent border radius, padding, and focus styles,
- optional label rendering,
- optional password visibility handling,
- optional prefix/suffix content,
- single-line fixed-height rule and multi-line expansion support.

`CustomTextField` and `AuthTextField` now delegate to `AppTextField`, preserving compatibility while keeping one core implementation.

## 4. Keyboard and Constraint Safety Patterns

Input dialogs/sheets use scroll/inset-safe composition where needed:
- `SingleChildScrollView` in dialog content,
- bottom inset handling in bottom sheets/dialogs for keyboard overlap,
- app-level tap-to-unfocus (`app.dart`) to reduce stuck keyboard state during transitions.

This pattern is used in auth recovery, review/complaint dialogs, settings/account dialogs, and support/search flows.

## 5. Major Interaction Patterns

### Shell and Drawer Motion
- Drawer + layered card transforms in `MainWrapper`.
- Animated shell content switching and menu reveal interactions.

### Appointment UX Motion
- Action Required cards and dialog interactions.
- Realtime countdown visuals (`LiveCountdownBadge`) for waiting-state awareness.

### Doctors/Map Motion
- `ClinicLocationMapSection` isolates map interaction and animated section behavior.
- Guarded map actions reduce timing-related map errors.

### Offline Indicator Motion
- `OfflineModeGuard` renders a non-blocking floating glassmorphism pill at shell level.
- Connectivity loss triggers a top-down animated entrance; reconnection hides it above the viewport.
- `IgnorePointer` keeps underlying screens interactive while the indicator is visible.
- Visual treatment uses blur, translucent deep-slate background, subtle border/shadow, and compact warning iconography.

## 6. Shared Components Frequently Used

- `AppTextField`
- `PrimaryButton`
- `CustomSnackbar`
- `AppointmentCard`
- `PessimisticSwitch`
- `AppStyles` helpers for cards, gradients, and shadows
- `OfflineModeGuard` for global connectivity feedback
