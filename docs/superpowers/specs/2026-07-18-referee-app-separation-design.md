# Referee App Separation — Design

**Date:** 2026-07-18
**Status:** Approved

## Background

The Khomasi mobile app (`mobile/`, since renamed on disk to `player/`) was built as a
single multi-role app serving both players and referees, a constraint of the original
university project. The repo now contains:

- `player/` — the full former mobile app (Dart package `khomasi`, Android id
  `com.example.khomasi`), containing both player and referee flows, routed by
  `UserProvider.isReferee` in `auth_wrapper.dart`, `login_page.dart`, and
  `signup_page.dart` (signup has a player/referee role selector).
- `referee/` — a bare `flutter create` skeleton (package `referee`, Android id
  `com.example.referee`, Android + iOS only, no Firebase).
- `admin/` — Flutter admin app (untouched by this work).

The git rename `mobile/` → `player/` happened on disk but is not yet committed.

## Goal

Two standalone, single-purpose Flutter apps sharing the same Firebase backend:

- `player/` — players only.
- `referee/` — referees only.

## Decisions (agreed with user)

1. **Shared code is copied into each app** (no shared package). Each app is fully
   standalone and independently buildable. Accepted trade-off: future fixes to shared
   files must be applied in both apps.
2. **Referee app gets its own Firebase identity.** Android package stays
   `com.example.referee` so both apps can be installed side by side. The user
   registers this package as a new Android app in the existing Firebase project and
   provides the downloaded `google-services.json`. The referee entry in
   `firebase_options.dart` is derived from that file.
3. **Player app is stripped of referee code** — pages, components, role selector, and
   `isReferee` routing.
4. **Referee accounts self-register in the referee app.** Its signup screen always
   creates `role: referee` (selector removed). Player signup always creates
   `role: player`.
5. **Construction approach: clone & prune.** The referee app is a copy of the working
   player app (proven Gradle/Firebase/manifest/fonts/assets config) with player-only
   code deleted, rather than building up from the bare skeleton.

## Referee app

### What is copied

Replace the `referee/` skeleton with a copy of `player/`, excluding:

- Build artifacts and junk: `build/`, `hs_err_pid*.log`, `replay_pid*.log`.
- Desktop/web platforms: `web/`, `windows/`, `linux/`, `macos/` (referee app is
  Android + iOS, matching the skeleton's scope).
- Project-level infra that stays with `player/`: `cloudflare-worker/`, `database/`,
  `hosting/`, `docs/`, `screenshots/`, `firebase.json`, `firestore.rules`,
  `storage.rules`, `khomasi.iml`.
- Player test assets: `test/goldens/`, `test/design_preview.dart` (a minimal
  `widget_test.dart` is kept/adapted).

### lib/ contents — the referee closure (25 files + main.dart)

Computed as the transitive `package:khomasi/` import closure of the referee entry
points, with the `root_page.dart` edge cut (removed by the adaptations below):

- **Pages:** `referee_page.dart`, `referee_profile_page.dart`,
  `active_match_page.dart`, `login_page.dart`, `signup_page.dart`,
  `settings_page.dart`, `suspended_screen.dart`
- **Components:** `referee_match_card.dart`, `score_board.dart`, `match_timer.dart`
- **Providers:** `auth_provider.dart`, `user_provider.dart`, `theme_provider.dart`,
  `locale_provider.dart`
- **Services:** `auth_service.dart`, `location_service.dart`,
  `notification_services.dart`
- **Models:** `user_model.dart`, `match_model.dart`
- **Theme:** `app_colors.dart`, `app_text.dart`, `app_theme.dart`
- **Other:** `auth_wrapper.dart`, `firebase_options.dart`,
  `l10n/app_localizations.dart`
- **Adapted:** `main.dart`

All other lib files (~44: booking, leaderboard, chat, payments, deep links, player
profile, etc.) are deleted from the referee copy.

### Package rename

- `pubspec.yaml` name: `khomasi` → `referee`.
- All imports: `package:khomasi/` → `package:referee/` (mechanical rewrite).
- Dependencies not imported by any closure file are removed from `pubspec.yaml`
  (e.g. deep-link and payment-related packages; `url_launcher` stays — used by
  `referee_page.dart`).

### Adapted files

- **`main.dart`** — registers only `ThemeProvider`, `AuthProvider`, `UserProvider`,
  `LocaleProvider`; drops `DeepLinkService`, `MatchProvider`, `LeaderboardProvider`;
  keeps Firebase init, FCM background handler, and `NotificationService`.
- **`auth_wrapper.dart`** — no guest mode: unauthenticated → `LoginPage`.
  Authenticated referee → `RefereePage`. Authenticated **player** → wrong-app screen
  ("هذا حساب لاعب — استخدم تطبيق خماسي") with a sign-out action. Suspension gate and
  warnings watcher are kept.
- **`login_page.dart`** — after login, player-role accounts get the wrong-app
  message and are signed out; referees go to `RefereePage`. `root_page` import
  removed.
- **`signup_page.dart`** — role selector removed; always creates `role: referee`;
  navigates to `RefereePage`. `root_page` import removed.

### Android / iOS identity

- Android: `namespace` and `applicationId` → `com.example.referee`;
  `MainActivity.kt` moved to `kotlin/com/example/referee/` with its package line
  updated; app label → "خماسي حكم".
- `google-services.json`: **user-provided step.** Register Android app
  `com.example.referee` in the Firebase console (same project) and place the
  downloaded file at `referee/android/app/google-services.json`. The Android entry
  in `firebase_options.dart` (appId, api key) is then derived from it. Until this
  file arrives, the referee app is complete but will not build.
- iOS: bundle identifier renamed to `com.example.referee`; would need its own
  `GoogleService-Info.plist` if ever built (secondary — no macOS build machine).

## Player app cleanup

- **Delete:** `pages/referee_page.dart`, `pages/referee_profile_page.dart`,
  `pages/active_match_page.dart`, `components/referee_match_card.dart`,
  `components/score_board.dart`, `components/match_timer.dart`, and
  `components/referee_stats.dart` (dead code — imported by nothing).
- **`auth_wrapper.dart`** — authenticated **referee** → wrong-app screen
  ("استخدم تطبيق الحكم") with sign-out; otherwise unchanged (guest mode stays).
- **`login_page.dart`** — referee-role login gets the wrong-app message and is
  signed out.
- **`signup_page.dart`** — role selector removed; always creates `role: player`.
- The `UserRole` enum, `role` field, and Firestore data model are unchanged — same
  backend, same `firestore.rules`.

## Backend

No changes. Both apps use the same Firebase project, Auth users, Firestore
collections, and security rules. FCM token refresh works per-device per-app as
today.

## Error handling

- Wrong-role login (both apps): clear Arabic message naming the correct app, then
  sign-out — the account is never left half-logged-in in the wrong app.
- Missing `google-services.json` in referee app: documented in `referee/README.md`
  as the single setup step.

## Verification

1. `flutter analyze` clean in both `player/` and `referee/`.
2. `flutter build apk --debug` succeeds for `player/` immediately, and for
   `referee/` once `google-services.json` is provided.
3. Manual smoke test: referee login in referee app reaches `RefereePage`; player
   login in player app reaches `RootPage`; wrong-role logins show the wrong-app
   screen and sign out; referee signup creates a referee account.

## Out of scope

- Admin app changes.
- Moving project-level infra (`firestore.rules`, `hosting/`, etc.) out of
  `player/` to the repo root.
- Any feature changes beyond the separation.
