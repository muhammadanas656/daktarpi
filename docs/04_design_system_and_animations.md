# DaktarPai - Design System and Animations

## 1. Design System Overview

The app uses centralized theme tokens in `lib/core/theme/` plus shared widgets in `lib/presentation/widgets/`.

Core token files:
- `app_colors.dart`
- `app_text_styles.dart`
- `app_dimens.dart`
- `app_shapes.dart`
- `app_motion.dart`
- `app_styles.dart`

## 2. Visual Language

Primary UI patterns:
- green-centered brand accents (`AppColors.primaryGreen`)
- white card surfaces with subtle border/shadow
- rounded controls with compact iconography
- clear text hierarchy using `textDark`, `textLight`, and `textGrey`
- Amber warning containers (`Colors.amber.withValues(alpha: 0.1)`) are used for temporary grace-period delays (e.g., the `WAITING` status banner in Account Activity).

## 3. Doctors UI and Map Experience

### 3.1 Modular Map Section

`doctor_details_screen.dart` now delegates map/navigation rendering to:
- `clinic_location_map_section.dart`

This section includes:
- map height transitions between compact and navigation modes
- top navigation chip with animated distance/loading state
- direction/locator action menus with animated expand/collapse

### 3.2 Safe Map Interaction Pattern

`ClinicLocationMapSection` uses:
- `onMapReady` + local readiness flag
- post-frame guarded map actions (`_runMapAction` / `_moveMapSafely`)

This reduces layout-timing map errors when rapidly navigating between clinics.

### 3.3 Doctor Details Refresh UX

`DoctorDetailsScreen` content is now wrapped in `RefreshIndicator` so failed or stale detail/schedule loads can be retried in-place.

## 4. Appointment UX Components

### 4.1 Payment Success Dialog

`dummy_payment_screen.dart` includes:
- `Add to Calendar` outlined action
- `Done` primary action

### 4.2 My Appointments Interactions

`my_appointments_screen.dart` includes:
- scroll-safe action sheet (`isScrollControlled`, `SingleChildScrollView`)
- pending review carousel (`Action Required` cards)
- inline review dialog flow
- pull-to-refresh support in empty and non-empty list states

### 4.3 Account Activity Review Dialog

`review_dialog.dart` provides:
- responsive inset padding
- `SingleChildScrollView` for small-screen safety
- star rating + optional comment input
- submit/cancel actions with loading state

## 5. Motion and Interaction Patterns

Current motion patterns:
- drawer transforms and shell transitions in `MainWrapper`
- map expansion, switchers, and menu rotations in map section
- stateful dialog transitions in settings/review/security flows

## 6. Reliability-Focused UI Patterns

Recent defensive UI updates:
- `heroTag: null` for clustered FABs to avoid hero-tag collisions
- guarded map move operations to avoid pre-layout rendering exceptions
- pull-to-refresh availability on major list/detail screens

## 7. Shared Components Frequently Used

- `PrimaryButton`
- `CustomSnackbar`
- `AppointmentCard`
- `PessimisticSwitch`
- `AppStyles` card/surface patterns
