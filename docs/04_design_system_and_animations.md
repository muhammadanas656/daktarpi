# DaktarPai — Design System & Animations

## 1. Design System Overview

DaktarPai uses a custom design system with centralized tokens for colors, typography, spacing, shapes, motion, and component styles. The system supports light and dark themes.

## 2. Color Palette

**File:** [app_colors.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_colors.dart)

| Token | Hex | Usage |
|---|---|---|
| `primaryGreen` | `#00C689` | Primary brand color, buttons, accents, success states |
| `textDark` | `#1A1A1A` | Primary text, headings |
| `textLight` | `#626F8D` | Secondary/body text |
| `textGrey` | `#9E9E9E` | Tertiary text, disabled states |
| `borderColor` | `#E0E0E0` | Card borders, input borders |
| `dangerRed` | `#E53935` | Destructive actions, errors |
| `cyanHeader` | `#E0F7FA` | Header backgrounds, card headers |
| `bgColor` / `scaffoldBackground` | `#FBFBFB` | Page background |
| `lightGreenBg` | `#E0F7FA` | Gradient start, light accents |
| `hintText` | `#C4C4C4` | Input field placeholders |
| `infoBlue` | `#2979FF` | Informational badges, links |

### Additional In-Use Colors

Screens also use these directly (not from AppColors):
- Navigation blue: `Colors.blueAccent` (map markers, user location)
- Warning orange: `Colors.orange` (recovery mode, 2FA backup)
- Gradient: `#E8F5E9` (page gradient end color)
- Dark theme surface: `#121212`, `#1E1E1E`

## 3. Typography

**File:** [app_text_styles.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_text_styles.dart)

Font family: **Google Fonts — Poppins** (loaded via `google_fonts` package)

| Style | Size | Weight | Color |
|---|---|---|---|
| `h1` | 24px | Bold | textDark |
| `h2` | 20px | Bold | textDark |
| `h3` | 18px | SemiBold (w600) | textDark |
| `body` | 14px | Normal | textLight |
| `bodySmall` | 12px | Normal | textGrey |
| `bodyBold` | 14px | SemiBold (w600) | textDark |
| `button` | 16px | SemiBold (w600) | White |
| `label` | 14px | Medium (w500) | textLight |

## 4. Spacing & Dimensions

**File:** [app_dimens.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_dimens.dart)

Contains constants for:
- Page horizontal/vertical padding
- Elevation levels (none, low, medium, high)
- Standard spacing increments

## 5. Shapes

**File:** [app_shapes.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_shapes.dart)

Centralized `BorderRadius` tokens:
- `sm` — small radius (inputs)
- `md` — medium radius (cards, buttons)
- `lg` — large radius (modals, dialogs)

## 6. Motion / Animation Tokens

**File:** [app_motion.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_motion.dart)

| Token | Value | Usage |
|---|---|---|
| `fast` | 200ms | Quick micro-interactions |
| `standard` / `defaultDuration` | 300ms | Most transitions, AnimatedSwitcher, AnimatedContainer |
| `slow` | 400ms | Larger layout shifts |
| `snackbarVisible` | 4 seconds | Snackbar display duration |
| `emphasized` curve | `Curves.easeOutBack` | Bouncy emphasis |
| `standardCurve` | `Curves.easeInOut` | Smooth standard transitions |

## 7. Surface Styles

**File:** [app_styles.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_styles.dart)

| Style | Description |
|---|---|
| `pageGradient` | `LinearGradient` from `lightGreenBg` → white → white → light green |
| `pagePadding` | Uniform page padding from `AppDimens` |
| `cardShadow` | Subtle `BoxShadow` (5% opacity, 10 blur, 4 offset) |
| `cardRadius` | Uses `AppShapes.lg` |
| `surfaceCard()` | Full card `BoxDecoration` (white, border, shadow, radius) |

## 8. Theme Configuration

**File:** [app_theme.dart](file:///C:/skills%20development/daktarpi/lib/core/theme/app_theme.dart)

### Light Theme

- `useMaterial3: true`
- `scaffoldBackgroundColor`: `#FBFBFB`
- `ColorScheme.fromSeed` with `primaryGreen`
- `ElevatedButtonTheme`: green background, white text, `AppShapes.lg` border radius, no elevation
- `InputDecorationTheme`: white fill, `AppShapes.md` border, green focus border
- `textTheme`: `GoogleFonts.poppinsTextTheme()`

### Dark Theme

- `brightness: Brightness.dark`
- `scaffoldBackgroundColor`: `#121212`
- Input fill: `#1E1E1E`
- Grey borders instead of white
- Same button and font configuration

### Theme Switching

**Files:** [settings_notifier.dart](file:///C:/skills%20development/daktarpi/lib/features/settings/presentation/settings_notifier.dart), [app.dart](file:///C:/skills%20development/daktarpi/lib/app.dart)

`SettingsNotifier.instance.themeMode` drives `MaterialApp.router`'s `themeMode` property through an `AnimatedBuilder` listener. The user can choose System / Light / Dark from Settings.

## 9. Animations Catalog

### Page-Level Animations

| Animation | Location | Type | Details |
|---|---|---|---|
| Splash screen gradient | `splash_screen.dart` | Static gradient | 3-color gradient with primaryGreen at 10% opacity |
| Auth page gradient | Login/Signup/Verify2FA | `AppStyles.pageGradient` | 4-stop linear gradient |
| Map height transition | `doctor_details_screen.dart` | `AnimatedContainer` | 150px → 350px when navigating |
| Distance bar expand | `doctor_details_screen.dart` | `AnimatedContainer` | Expands to show controls |
| FAB reveal | `doctor_details_screen.dart` | `AnimatedSize` | Direction/locator menu buttons |
| FAB rotation | `doctor_details_screen.dart` | `AnimatedRotation` | 180° turn for open/close icons |

### Widget-Level Animations

| Animation | Widget | Type |
|---|---|---|
| Mode switching (OTP ↔ Recovery) | `verify_2fa_screen.dart` | `AnimatedSwitcher` + `AnimatedCrossFade` |
| Recovery assist fade-in | `verify_2fa_screen.dart` | `AnimatedOpacity` (5s delay) |
| Bottom nav indicator | `main_wrapper.dart` | `AnimatedPositioned` |
| Drawer slide | `main_wrapper.dart` | `AnimationController` + `Transform.translate` |
| Content scale on drawer | `main_wrapper.dart` | `Transform.scale` + `ClipRRect` |
| Offline banner | `offline_mode_guard.dart` | `AnimatedContainer` (h: 0 ↔ 40) |
| Lock screen overlay | `inactivity_lock_guard.dart` | `AnimatedOpacity` + gradient |
| 2FA setup wizard | `settings_screen.dart` | `AnimatedSwitcher` per step |
| Settings tile icons | `settings_screen.dart` | Gradient icon containers |
| Snackbar entry | `custom_snackbar.dart` | Built-in Material animation |

### Gesture Animations

| Gesture | Location | Behavior |
|---|---|---|
| Drawer swipe | `main_wrapper.dart` | `GestureDetector` with velocity-based snap |
| Map pan detection | `doctor_details_screen.dart` | `onPositionChanged` with `hasGesture` flag |
| Distance bar tap | `doctor_details_screen.dart` | Toggle expand state |

## 10. Shared Widgets

**Directory:** [presentation/widgets/](file:///C:/skills%20development/daktarpi/lib/presentation/widgets)

| Widget | File | Purpose |
|---|---|---|
| `PrimaryButton` | `primary_button.dart` | Green CTA button with loading state |
| `SocialButton` | `social_button.dart` | OAuth login buttons (Google) |
| `AuthTextField` | `auth_text_field.dart` | Styled input for auth screens |
| `AuthCodeInput` | `auth_code_input.dart` | Pin-code input (6-digit OTP, 8-char recovery) |
| `AppTextField` | `app_text_field.dart` | General-purpose input field |
| `CustomTextField` | `custom_text_field.dart` | Alternative styled text field |
| `CustomSearchBar` | `custom_search_bar.dart` | Search input with icons |
| `CustomSnackbar` | `custom_snackbar.dart` | Themed snackbar (success, error, info, warning) |
| `PessimisticSwitch` | `pessimistic_switch.dart` | Switch that waits for async callback before toggling |
| `AppointmentCard` | `appointment_card.dart` | Appointment list item card |
| `DoctorListCard` | `doctor_list_card.dart` | Doctor card for list views |
| `FeaturedDoctorCard` | `featured_doctor_card.dart` | Horizontal featured doctor card |
| `HomeFeaturedDoctorCard` | `home_featured_doctor_card.dart` | Compact featured card for home screen |
| `HomePopularDoctorCard` | `home_popular_doctor_card.dart` | Popular doctor card for home screen |
| `AppNetworkImage` | `app_network_image.dart` | Network image with fallback |

### Core Widgets

| Widget | File | Purpose |
|---|---|---|
| `AppErrorFallback` | `core/widgets/app_error_fallback.dart` | Replaces red error screen; "Go Home" button |
| `RouteErrorScreen` | `core/widgets/route_error_screen.dart` | 404 / invalid route screen |
