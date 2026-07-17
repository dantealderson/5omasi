# خماسي — مكتب العمليات (Khomasi Admin)

Desktop/web admin app for Khomasi. Replaces the temporary in-app test page
that used to live in the mobile app (`test_create_match.dart`, now removed).

Runs against the **same Firebase project** (`khomasi-177f3`) and the same
Firestore collections as the mobile app — matches and stadiums created here
appear in the players' app instantly.

## Features

- **لوحة التحكم** — live fixtures board: open matches, active stadiums, today's fixtures.
- **المباريات** — create one-off or weekly recurring matches (with the same
  conflict check the test page had), delete upcoming matches.
- **الملاعب** — add stadiums (image upload, location, sizes, amenities),
  soft-delete (sets `isActive: false`).

## Access control

Sign-in uses the same Firebase Auth email/password accounts as the mobile app,
and the login page can also create a new account. Access to the desk itself is
gated by the `admins/{uid}` Firestore collection:

- **First run (no admins exist):** whoever signs in first can claim the first
  admin seat with one click.
- **Afterwards:** new accounts land on a "request access" screen; existing
  admins approve/reject requests, add admins by email, or remove admins from
  the **المشرفون** page.

`firestore.rules` (in `../mobile/`) includes matching rules for `admins` and
`adminRequests` — note the bootstrap caveat documented there.

## Design

Shares the mobile app's **Midnight Club** design system — identical palette
(`lib/theme/app_colors.dart`), typography (Reem Kufi / IBM Plex Sans Arabic /
IBM Plex Mono) and component language, laid out as a desktop shell with a
right-hand (RTL) navigation rail.

## Run

```sh
flutter pub get
flutter run -d windows   # or: flutter run -d chrome
```
