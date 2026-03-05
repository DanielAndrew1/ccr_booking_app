# CCR App Structure

This folder layout is organized by feature first, then by shared layers.

## Top-Level

- `lib/core`: app-wide foundations (theme, root, shared exports, constants).
- `lib/localization`: language/locale logic.
- `lib/models`: plain data models.
- `lib/providers`: state providers.
- `lib/services`: API/storage/business services.
- `lib/pages`: screens, grouped by feature.
- `lib/widgets`: reusable UI widgets, grouped by type.

## Pages

- `lib/pages/auth`: login/register.
- `lib/pages/home`: home page + its local widget/logic file.
- `lib/pages/bookings`: bookings list + edit booking.
- `lib/pages/calendar`: calendar screen.
- `lib/pages/profile`: profile + settings + about + edit info.
- `lib/pages/users`: employees + clients management.
- `lib/pages/inventory`: inventory + product details.
- `lib/pages/messages`: messages placeholder/future chat.
- `lib/pages/system`: system-level pages (no internet, etc.).
- `lib/pages/add`: add/create forms.
- `lib/pages/onboarding`: onboarding flow screens.

## Widgets

- `lib/widgets/navigation`: nav/app bar widgets.
- `lib/widgets/feedback`: snackbar/loader/dialog widgets.
- `lib/widgets/display`: visual display widgets (bg, avatar).
- `lib/widgets/inputs`: text fields/search/buttons.
- `lib/widgets/tiles`: tile/card-style reusable components.

## Rules For New Code

- Put feature-specific UI in that feature folder under `pages/`.
- Keep shared reusable widgets in `widgets/` by type.
- If a screen file grows too much, split to:
  - `page.dart` for screen layout/state
  - `page_widgets.dart` (or `part`) for local builders/helpers
- Prefer `package:ccr_booking/core/imports.dart` for shared imports.
- Keep one responsibility per service/provider file.
