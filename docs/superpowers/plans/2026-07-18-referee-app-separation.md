# Referee App Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the combined Khomasi mobile app into two standalone Flutter apps — `player/` (players only) and `referee/` (referees only) — sharing the same Firebase backend, per the approved spec `docs/superpowers/specs/2026-07-18-referee-app-separation-design.md`.

**Architecture:** Clone the working `player/` app over the bare `referee/` skeleton, prune it to the referee's 25-file import closure, rename the Dart package `khomasi` → `referee`, give it the Android identity `com.example.referee`, then strip referee code out of `player/`. Both apps get a `WrongAppScreen` + sign-out guard for accounts of the other role.

**Tech Stack:** Flutter (Dart SDK ^3.8.1), Firebase (Auth, Firestore, Messaging), Provider, Windows dev machine (PowerShell + Git Bash).

## Global Constraints

- **Execute in the main working tree, NOT a git worktree.** The `mobile/` → `player/` rename exists only as uncommitted working-tree state; a worktree would not contain it.
- **Never run `git add -A`, `git add .`, or `git commit -a`.** The repo has unrelated in-flight changes under `admin/` that must stay unstaged. Stage explicit paths only (`git add player mobile`, `git add referee`, etc.). Before every commit, run `git status --short` and confirm nothing under `admin/` is staged.
- All user-facing strings are Arabic; source files are UTF-8. When rewriting files with shell tools, use the **Bash tool** (Git Bash `sed` preserves UTF-8); PowerShell 5.1 `Set-Content` defaults to UTF-16 and will corrupt Dart files.
- `robocopy` exit codes 0–7 mean success; ≥8 is failure. In PowerShell check `$LASTEXITCODE -lt 8`, or run it via the Bash tool with `robocopy ... ; [ $? -lt 8 ]`.
- Run `flutter` commands from inside the app folder (`player/` or `referee/`).
- Identities: player = Dart package `khomasi`, Android `com.example.khomasi`; referee = Dart package `referee`, Android `com.example.referee`, app label **خماسي حكم**. Both use Firebase project `khomasi-177f3`.
- **The referee app cannot `flutter build` until the user registers `com.example.referee` in Firebase and provides `google-services.json`.** This is expected and not a task failure; `flutter analyze` and `flutter test` work without it and are the per-task gates.
- Analyze gate = "no new issues vs the baseline recorded in Task 1" (the codebase may have pre-existing infos/warnings). Zero **errors** always required.
- End every commit message with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: Commit the pending `mobile` → `player` rename and record analyze baseline

**Files:**
- Delete: `player/hs_err_pid*.log`, `player/replay_pid*.log` (untracked JVM crash logs)
- Commit: the already-on-disk rename `mobile/**` → `player/**`

**Interfaces:**
- Produces: a clean tracked `player/` tree that later tasks diff against; analyze baseline file in the scratchpad.

- [ ] **Step 1: Delete crash-log junk so it never gets tracked**

Bash tool:
```bash
cd /d/khomasi_workspace/player && rm -f hs_err_pid*.log replay_pid*.log
```

- [ ] **Step 2: Record the player analyze baseline**

```bash
cd /d/khomasi_workspace/player && flutter analyze > "$SCRATCHPAD/player-analyze-baseline.txt" 2>&1; tail -3 "$SCRATCHPAD/player-analyze-baseline.txt"
```
(`$SCRATCHPAD` = the session scratchpad directory.) Note the issue count — later tasks must not add to it.

- [ ] **Step 3: Stage the rename (deletions of mobile/, additions of player/) — nothing else**

```bash
cd /d/khomasi_workspace && git add mobile player && git status --short | grep "^[AMDR]" | grep -v "mobile\|player" || true
```
Expected: the final grep prints nothing (no staged paths outside mobile/player). If anything under `admin/` or elsewhere appears staged, unstage it before continuing.

- [ ] **Step 4: Commit**

```bash
cd /d/khomasi_workspace && git commit -m "Rename mobile app folder to player

The combined mobile app becomes the player app; a separate referee app
follows in referee/.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
Expected: commit succeeds; `git status` no longer shows `mobile/` deletions.

---

### Task 2: Replace the `referee/` skeleton with a pruned copy of `player/`

**Files:**
- Delete: entire current `referee/` (default `flutter create` skeleton, nothing custom)
- Create: `referee/` = copy of `player/` minus exclusions, minus 44 player-only lib files

**Interfaces:**
- Produces: `referee/lib` containing exactly `main.dart` + the 25 closure files listed below; `referee/android`, `referee/ios`, `referee/assets`, `referee/images`, `referee/test` present.

- [ ] **Step 1: Delete the skeleton and copy player with exclusions**

PowerShell tool (robocopy `/`-flags get mangled by Git Bash path conversion):
```powershell
Remove-Item -Recurse -Force D:\khomasi_workspace\referee
robocopy D:\khomasi_workspace\player D:\khomasi_workspace\referee /E /XD build web windows linux macos cloudflare-worker database hosting docs screenshots goldens .dart_tool .idea /XF hs_err_pid*.log replay_pid*.log firebase.json firestore.rules storage.rules khomasi.iml google-services.json GoogleService-Info.plist design_preview.dart local.properties pubspec.lock
if ($LASTEXITCODE -lt 8) { "COPY-OK" }
```
Expected: `COPY-OK` (robocopy exit 1–3 = files copied; the PowerShell tool may report a nonzero exit — the `COPY-OK` line is the success signal).

- [ ] **Step 2: Delete the 44 player-only lib files**

Bash tool, from `/d/khomasi_workspace/referee/lib`:
```bash
cd /d/khomasi_workspace/referee/lib && rm -f \
  components/info_row.dart components/match_card.dart components/my_button.dart \
  components/my_textfield.dart components/my_wide_button.dart components/player_action_card.dart \
  components/referee_stats.dart components/service_icon.dart components/square_tile.dart \
  components/stats_widget.dart \
  models/leaderboard_model.dart models/match_history_model.dart models/stadium_model.dart \
  models/transaction_model.dart \
  pages/booking_page.dart pages/contact_us_page.dart pages/edit_profile_page.dart \
  pages/faq_page.dart pages/home_page.dart pages/leaderboard_page.dart pages/match_chat_page.dart \
  pages/match_history_page.dart pages/player_lockout_screen.dart pages/player_profile_page.dart \
  pages/profile_page.dart pages/rate_players_page.dart pages/root_page.dart \
  providers/leaderboard_provider.dart providers/match_provider.dart providers/providers.dart \
  services/deep_link_service.dart services/image_upload_service.dart services/leaderboard_service.dart \
  services/match_service.dart services/match_validation_service.dart services/payment_service.dart \
  services/player_rating_service.dart services/push_notification_sender.dart services/stadium_service.dart \
  services/team_balance_service.dart services/token_service.dart services/user_service.dart \
  services/waiting_list_service.dart && echo PRUNE-OK
```
Expected: `PRUNE-OK`.

- [ ] **Step 3: Verify the tree matches the closure exactly**

```bash
cd /d/khomasi_workspace/referee/lib && find . -name "*.dart" | sort
```
Expected output — exactly these 26 files, nothing more:
```
./auth_wrapper.dart
./components/match_timer.dart
./components/referee_match_card.dart
./components/score_board.dart
./firebase_options.dart
./l10n/app_localizations.dart
./main.dart
./models/match_model.dart
./models/user_model.dart
./pages/active_match_page.dart
./pages/login_page.dart
./pages/referee_page.dart
./pages/referee_profile_page.dart
./pages/settings_page.dart
./pages/signup_page.dart
./pages/suspended_screen.dart
./providers/auth_provider.dart
./providers/locale_provider.dart
./providers/theme_provider.dart
./providers/user_provider.dart
./services/auth_service.dart
./services/location_service.dart
./services/notification_services.dart
./theme/app_colors.dart
./theme/app_text.dart
./theme/app_theme.dart
```
Also verify platform/asset dirs came over and infra did not:
```bash
cd /d/khomasi_workspace/referee && ls -d android ios assets images test lib && ! ls -d web windows linux macos hosting database cloudflare-worker docs 2>/dev/null && echo DIRS-OK
```
Expected: `DIRS-OK`.

- [ ] **Step 4: Commit**

```bash
cd /d/khomasi_workspace && git add referee && git status --short | grep "^[AMDR]" | grep -v referee || true
```
Expected: final grep prints nothing. Then:
```bash
git commit -m "referee: clone player app pruned to the referee closure

Copy of player/ minus build artifacts, desktop/web platforms, project
infra, and the 44 player-only lib files. Package rename and role
adaptations follow.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Rename Dart package to `referee`, prune pubspec, `flutter pub get`

**Files:**
- Modify: `referee/pubspec.yaml` (name, description, remove 4 deps)
- Modify: every `referee/**/*.dart` importing `package:khomasi/`

**Interfaces:**
- Produces: package `referee` — all later tasks import `package:referee/...`. Dependencies available to referee code: google_sign_in, url_launcher, firebase_core, firebase_auth, cloud_firestore, provider, shared_preferences, cupertino_icons, geolocator, firebase_messaging, flutter_local_notifications.

- [ ] **Step 1: Edit pubspec name/description and remove unused deps**

In `referee/pubspec.yaml`:
- `name: khomasi` → `name: referee`
- `description: "A new Flutter project."` → `description: "Khomasi referee app."`
- Delete these 4 dependency lines (no closure file imports them): `image_picker: ^1.0.4`, `http: ^1.1.0`, `firebase_storage: ^13.0.4`, `share_plus: ^12.0.1`
- Keep everything else, including the `assets:` and `fonts:` sections unchanged.

- [ ] **Step 2: Rewrite import prefixes**

Bash tool:
```bash
cd /d/khomasi_workspace/referee && grep -rl "package:khomasi" lib test --include="*.dart" | xargs sed -i 's|package:khomasi/|package:referee/|g' && grep -r "package:khomasi" lib test --include="*.dart" | wc -l
```
Expected: final count `0`.

- [ ] **Step 3: Fetch dependencies**

```bash
cd /d/khomasi_workspace/referee && flutter pub get
```
Expected: `Got dependencies!` (a new `pubspec.lock` is generated — commit it).

- [ ] **Step 4: Commit**

```bash
cd /d/khomasi_workspace && git add referee && git commit -m "referee: rename Dart package to referee and prune unused deps

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
(`flutter analyze` still fails here — main.dart/auth_wrapper still reference deleted files; fixed in Tasks 4–6.)

---

### Task 4: Adapt referee `main.dart`

**Files:**
- Modify: `referee/lib/main.dart` (full replacement below)

**Interfaces:**
- Consumes: `AuthWrapper` from `package:referee/auth_wrapper.dart` (adapted in Task 5), providers, `NotificationService.initialize()`.
- Produces: `MyApp` (StatelessWidget) and top-level `navigatorKey` — registered providers: ThemeProvider, AuthProvider, UserProvider, LocaleProvider only.

- [ ] **Step 1: Replace the file contents entirely with:**

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:referee/firebase_options.dart';
import 'package:referee/providers/theme_provider.dart';
import 'package:referee/providers/auth_provider.dart';
import 'package:referee/providers/user_provider.dart';
import 'package:referee/providers/locale_provider.dart';
import 'package:referee/auth_wrapper.dart';
import 'package:referee/services/notification_services.dart';

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Background message: ${message.notification?.title}');
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notifications
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            title: 'خماسي حكم',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            locale: localeProvider.flutterLocale,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}
```
Changes vs the player original: `package:referee/` imports; `DeepLinkService`, `MatchProvider`, `LeaderboardProvider` removed; `MyApp` is now stateless; title is خماسي حكم.

- [ ] **Step 2: Commit**

```bash
cd /d/khomasi_workspace && git add referee/lib/main.dart && git commit -m "referee: adapt app entrypoint (4 providers, no deep links)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Referee `WrongAppScreen` (TDD) and `auth_wrapper` adaptation

**Files:**
- Delete: `referee/test/widget_test.dart` (stale flutter-create counter test — can never pass against this app)
- Create: `referee/test/wrong_app_screen_test.dart`
- Create: `referee/lib/pages/wrong_app_screen.dart`
- Modify: `referee/lib/auth_wrapper.dart`

**Interfaces:**
- Produces: `WrongAppScreen({super.key, required VoidCallback onSignOut})` in `package:referee/pages/wrong_app_screen.dart`. Consumed by `auth_wrapper.dart` (this task) and by nothing else.
- Consumes: `AppTheme.dark()` from `package:referee/theme/app_theme.dart`; `context.palette` (falls back to `AppPalette.dark` when no theme extension — tests work with plain `MaterialApp` too).

- [ ] **Step 1: Delete the stale counter test and write the failing test**

```bash
rm /d/khomasi_workspace/referee/test/widget_test.dart
```
Create `referee/test/wrong_app_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:referee/pages/wrong_app_screen.dart';
import 'package:referee/theme/app_theme.dart';

void main() {
  testWidgets('WrongAppScreen shows player-account message and signs out',
      (tester) async {
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: WrongAppScreen(onSignOut: () => signedOut = true),
    ));

    expect(find.text('هذا حساب لاعب'), findsOneWidget);
    expect(
      find.text('هذا التطبيق مخصص للحكام فقط — استخدم تطبيق خماسي للاعبين.'),
      findsOneWidget,
    );

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pump();
    expect(signedOut, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /d/khomasi_workspace/referee && flutter test test/wrong_app_screen_test.dart
```
Expected: FAIL — `Error: Couldn't resolve the package 'referee/pages/wrong_app_screen.dart'` (file doesn't exist yet).

- [ ] **Step 3: Implement `referee/lib/pages/wrong_app_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:referee/theme/app_colors.dart';

/// Shown when a player account signs into the referee app. The account is
/// valid — it just belongs in the other app — so explain and offer sign-out.
class WrongAppScreen extends StatelessWidget {
  const WrongAppScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: p.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.swap_horiz_rounded,
                        size: 56, color: AppColors.gold),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'هذا حساب لاعب',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'هذا التطبيق مخصص للحكام فقط — استخدم تطبيق خماسي للاعبين.',
                    style: TextStyle(color: p.textMid, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onSignOut,
                      child: const Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /d/khomasi_workspace/referee && flutter test test/wrong_app_screen_test.dart
```
Expected: `All tests passed!`

- [ ] **Step 5: Adapt `referee/lib/auth_wrapper.dart`**

Three edits (the file was already import-renamed to `package:referee/` in Task 3):

1. Imports — replace
```dart
import 'package:referee/pages/root_page.dart';
```
with
```dart
import 'package:referee/pages/login_page.dart';
import 'package:referee/pages/wrong_app_screen.dart';
```

2. Unauthenticated branch — no guest mode in the referee app. Replace
```dart
    // Not authenticated - go to home as guest (skip login screen)
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      _lastInitializedUserId = null;
      return const RootPage();
    }
```
with
```dart
    // Not authenticated - referees must log in (no guest mode)
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      _lastInitializedUserId = null;
      return const LoginPage();
    }
```

3. Role routing — replace
```dart
            child: userProvider.isReferee
                ? const RefereePage()
                : const RootPage(),
```
with
```dart
            child: userProvider.isReferee
                ? const RefereePage()
                : WrongAppScreen(onSignOut: () => authProvider.signOut()),
```

- [ ] **Step 6: Commit**

```bash
cd /d/khomasi_workspace && git add referee/lib/pages/wrong_app_screen.dart referee/lib/auth_wrapper.dart referee/test && git commit -m "referee: login-only auth flow with wrong-app screen for player accounts

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Referee login/signup/auth-provider role adaptations + analyze gate

**Files:**
- Modify: `referee/lib/pages/login_page.dart`
- Modify: `referee/lib/pages/signup_page.dart`
- Modify: `referee/lib/providers/auth_provider.dart`

**Interfaces:**
- Consumes: `AuthProvider.signOut() → Future<void>`, `UserProvider.isReferee → bool`, existing `_showErrorDialog(String)` (login page) and `_showError(String)` (signup page) helpers.
- Produces: referee app compiles clean — `flutter analyze` gate for the whole referee lib.

- [ ] **Step 1: `login_page.dart` — remove the player route and guard both flows**

Remove the import:
```dart
import 'package:referee/pages/root_page.dart';
```

In `signIn()` (email flow), replace the role-branch navigation:
```dart
      // Navigate based on role
      if (userProvider.isReferee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootPage()),
          (route) => false,
        );
      }
```
with
```dart
      if (userProvider.isReferee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        // Player account in the referee app — sign out and point to the right app
        await authProvider.signOut();
        if (!mounted) return;
        _showErrorDialog('هذا حساب لاعب — استخدم تطبيق خماسي للاعبين.');
      }
```

In `signInWithGoogle()`, replace
```dart
      // Google sign-in defaults to player
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootPage()),
        (route) => false,
      );
```
with
```dart
      if (userProvider.isReferee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        // Player account in the referee app — sign out and point to the right app
        await authProvider.signOut();
        if (!mounted) return;
        _showError('هذا حساب لاعب — استخدم تطبيق خماسي للاعبين.');
      }
```

- [ ] **Step 2: `signup_page.dart` — referee-only signup**

Remove the import:
```dart
import 'package:referee/pages/root_page.dart';
```

Delete the field:
```dart
  String selectedRole = 'player'; // 'player' or 'referee'
```

In the email signup call, replace `role: selectedRole,` with `role: 'referee',`.

Replace the post-signup navigation:
```dart
      // Navigate based on selected role
      if (selectedRole == 'referee') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootPage()),
          (route) => false,
        );
      }
```
with
```dart
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RefereePage()),
        (route) => false,
      );
```

In `signUpWithGoogle()`, replace
```dart
      // Google signup defaults to player
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootPage()),
        (route) => false,
      );
```
with
```dart
      if (userProvider.isReferee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        // Existing player account signed in via Google — wrong app
        await authProvider.signOut();
        if (!mounted) return;
        _showError('هذا حساب لاعب — استخدم تطبيق خماسي للاعبين.');
      }
```

Delete the role-selector UI block in `build()` — the widget beginning with the comment `// Role selector` (a `SlideTransition` wrapping the player/referee toggle `Container`) through its closing `),`. Keep the `SizedBox(height: screenHeight * 0.025),` that follows it.

- [ ] **Step 3: `auth_provider.dart` — new Google users register as referees**

In `signInWithGoogle()`'s new-user creation block, replace
```dart
            role: UserRole.player,
```
with
```dart
            // New Google accounts in the referee app register as referees
            role: UserRole.referee,
```

- [ ] **Step 4: Analyze gate + tests**

```bash
cd /d/khomasi_workspace/referee && flutter analyze && flutter test
```
Expected: `No issues found!` (or only issues also present in the Task 1 baseline — zero errors either way) and `All tests passed!`. Fix any stragglers (typically leftover imports of deleted files) before committing.

- [ ] **Step 5: Commit**

```bash
cd /d/khomasi_workspace && git add referee/lib && git commit -m "referee: referee-only login and signup with wrong-role guards

Signup always creates role referee; player accounts logging in are
signed out with a message pointing at the player app.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Referee Android/iOS identity + README

**Files:**
- Modify: `referee/android/app/build.gradle.kts`
- Create: `referee/android/app/src/main/kotlin/com/example/referee/MainActivity.kt`
- Delete: `referee/android/app/src/main/kotlin/com/example/khomasi/` (whole dir)
- Modify: `referee/android/app/src/main/AndroidManifest.xml`
- Modify: `referee/ios/Runner.xcodeproj/project.pbxproj`, `referee/ios/Runner/Info.plist`
- Modify: `referee/README.md` (full replacement)

**Interfaces:**
- Produces: Android identity `com.example.referee`, label خماسي حكم. Build remains blocked on the user-provided `google-services.json` (documented in README) — that is expected.

- [ ] **Step 1: `build.gradle.kts` — change identity**

Replace `namespace = "com.example.khomasi"` with `namespace = "com.example.referee"` and `applicationId = "com.example.khomasi"` with `applicationId = "com.example.referee"`. Everything else (Firebase BoM, desugaring, multidex, google-services plugin) stays.

- [ ] **Step 2: Replace MainActivity**

Create `referee/android/app/src/main/kotlin/com/example/referee/MainActivity.kt`:
```kotlin
package com.example.referee

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```
(The khomasi MainActivity's deep-link MethodChannel is player-only.) Then:
```bash
rm -rf /d/khomasi_workspace/referee/android/app/src/main/kotlin/com/example/khomasi
```

- [ ] **Step 3: AndroidManifest — label + drop deep links**

In `referee/android/app/src/main/AndroidManifest.xml`:
- `android:label="khomasi"` → `android:label="خماسي حكم"`
- Delete the deep-link block (comment included):
```xml
            <!-- Deep link: khomasi://match/{matchId} -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="khomasi"/>
            </intent-filter>
```
Keep the launcher intent-filter, the FCM channel meta-data (`khomasi_matches` — same channel id is fine, it is app-local), and the flutterEmbedding meta-data.

- [ ] **Step 4: iOS identity (best-effort — no macOS build machine)**

```bash
cd /d/khomasi_workspace/referee && sed -i 's/com\.example\.khomasi/com.example.referee/g' ios/Runner.xcodeproj/project.pbxproj && grep -c "com.example.referee" ios/Runner.xcodeproj/project.pbxproj
```
Expected: count ≥ 3. In `ios/Runner/Info.plist`, set the display-name values (`CFBundleDisplayName` and/or `CFBundleName`) to `خماسي حكم` — check with `grep -n -A1 "CFBundle.*Name" ios/Runner/Info.plist` and edit the `<string>` values.

- [ ] **Step 5: Replace `referee/README.md` with:**

```markdown
# Khomasi Referee (خماسي حكم)

The referee companion app for the Khomasi platform. Referees browse available
matches, accept assignments, and manage live matches (score, timer, events).

Shares the Firebase backend (project `khomasi-177f3`) with the player app
(`../player`) and the admin app (`../admin`).

## One-time Firebase setup (required before first build)

The Android app id `com.example.referee` must be registered in the Firebase
project:

1. Firebase console → project **khomasi-177f3** → Project settings →
   Your apps → **Add app** → Android.
2. Package name: `com.example.referee`. Register, then download
   `google-services.json`.
3. Put the file at `android/app/google-services.json`.
4. In `lib/firebase_options.dart`, update the `android` entry from that file:
   - `appId` ← the `mobilesdk_app_id` of the client whose `package_name` is
     `com.example.referee`
   - `apiKey` ← that client's `api_key[0].current_key`

   All other fields (projectId, messagingSenderId, storageBucket) stay the same.

## Run

    flutter pub get
    flutter run
```

- [ ] **Step 6: Verify no khomasi identity remains, then commit**

```bash
cd /d/khomasi_workspace/referee && grep -rn "com.example.khomasi" android ios | grep -v Pods || echo IDENTITY-CLEAN
```
Expected: `IDENTITY-CLEAN`.
```bash
cd /d/khomasi_workspace && git add referee && git commit -m "referee: own Android/iOS identity com.example.referee and setup README

google-services.json for the new app id is a documented user step; the
app builds once it is provided.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Strip referee code out of the player app

**Files:**
- Delete: `player/lib/pages/referee_page.dart`, `player/lib/pages/referee_profile_page.dart`, `player/lib/pages/active_match_page.dart`, `player/lib/components/referee_match_card.dart`, `player/lib/components/referee_stats.dart`, `player/lib/components/score_board.dart`, `player/lib/components/match_timer.dart`, `player/test/widget_test.dart` (stale counter test, can never pass)
- Create: `player/lib/pages/wrong_app_screen.dart`, `player/test/wrong_app_screen_test.dart`
- Modify: `player/lib/auth_wrapper.dart`, `player/lib/pages/login_page.dart`, `player/lib/pages/signup_page.dart`, `player/test/design_preview.dart`

**Interfaces:**
- Produces: `WrongAppScreen({super.key, required VoidCallback onSignOut})` in `package:khomasi/pages/wrong_app_screen.dart` (player flavor — referee-account message).
- Consumes: `AuthProvider.signOut() → Future<void>`, `UserProvider.isReferee → bool`.

- [ ] **Step 1: Write the failing player test**

Create `player/test/wrong_app_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khomasi/pages/wrong_app_screen.dart';
import 'package:khomasi/theme/app_theme.dart';

void main() {
  testWidgets('WrongAppScreen shows referee-account message and signs out',
      (tester) async {
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: WrongAppScreen(onSignOut: () => signedOut = true),
    ));

    expect(find.text('هذا حساب حكم'), findsOneWidget);
    expect(
      find.text('هذا التطبيق مخصص للاعبين فقط — استخدم تطبيق خماسي حكم.'),
      findsOneWidget,
    );

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pump();
    expect(signedOut, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd /d/khomasi_workspace/player && flutter test test/wrong_app_screen_test.dart
```
Expected: FAIL — package `khomasi/pages/wrong_app_screen.dart` doesn't resolve.

- [ ] **Step 3: Implement `player/lib/pages/wrong_app_screen.dart`**

Same widget as the referee one with swapped copy — full content:
```dart
import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';

/// Shown when a referee account signs into the player app. The account is
/// valid — it just belongs in the other app — so explain and offer sign-out.
class WrongAppScreen extends StatelessWidget {
  const WrongAppScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: p.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.swap_horiz_rounded,
                        size: 56, color: AppColors.gold),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'هذا حساب حكم',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'هذا التطبيق مخصص للاعبين فقط — استخدم تطبيق خماسي حكم.',
                    style: TextStyle(color: p.textMid, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onSignOut,
                      child: const Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /d/khomasi_workspace/player && flutter test test/wrong_app_screen_test.dart
```
Expected: `All tests passed!`

- [ ] **Step 5: Delete the referee files**

```bash
cd /d/khomasi_workspace && git rm player/lib/pages/referee_page.dart player/lib/pages/referee_profile_page.dart player/lib/pages/active_match_page.dart player/lib/components/referee_match_card.dart player/lib/components/referee_stats.dart player/lib/components/score_board.dart player/lib/components/match_timer.dart player/test/widget_test.dart
```

- [ ] **Step 6: `player/lib/auth_wrapper.dart` — route referees to the wrong-app screen**

Replace the import
```dart
import 'package:khomasi/pages/referee_page.dart';
```
with
```dart
import 'package:khomasi/pages/wrong_app_screen.dart';
```
and the role routing
```dart
            child: userProvider.isReferee
                ? const RefereePage()
                : const RootPage(),
```
with
```dart
            child: userProvider.isReferee
                ? WrongAppScreen(onSignOut: () => authProvider.signOut())
                : const RootPage(),
```

- [ ] **Step 7: `player/lib/pages/login_page.dart` — guard both flows**

Remove the import `import 'package:khomasi/pages/referee_page.dart';`.

In `signIn()`, replace the role-branch:
```dart
      // Navigate based on role
      if (userProvider.isReferee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootPage()),
          (route) => false,
        );
      }
```
with
```dart
      if (userProvider.isReferee) {
        // Referee account in the player app — sign out and point to the right app
        await authProvider.signOut();
        if (!mounted) return;
        _showErrorDialog('هذا حساب حكم — استخدم تطبيق خماسي حكم.');
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootPage()),
          (route) => false,
        );
      }
```

In `signInWithGoogle()`, replace
```dart
      // Google sign-in defaults to player
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootPage()),
        (route) => false,
      );
```
with
```dart
      if (userProvider.isReferee) {
        // Referee account in the player app — sign out and point to the right app
        await authProvider.signOut();
        if (!mounted) return;
        _showError('هذا حساب حكم — استخدم تطبيق خماسي حكم.');
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootPage()),
          (route) => false,
        );
      }
```

- [ ] **Step 8: `player/lib/pages/signup_page.dart` — player-only signup**

Remove the import `import 'package:khomasi/pages/referee_page.dart';`.
Delete the field `String selectedRole = 'player'; // 'player' or 'referee'`.
Replace `role: selectedRole,` with `role: 'player',`.
Replace the post-signup role-branch navigation with:
```dart
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootPage()),
        (route) => false,
      );
```
Delete the role-selector UI block in `build()` (the widget starting at the `// Role selector` comment — a `SlideTransition` wrapping the toggle `Container` — through its closing `),`), keeping the `SizedBox(height: screenHeight * 0.025),` after it. The Google signup flow is unchanged (already player-only).

- [ ] **Step 9: `player/test/design_preview.dart` — drop the referee preview**

- Delete the unused import `import 'package:khomasi/components/score_board.dart';`
- Delete the whole `_refereeHeader` function (from the doc comment `/// Faithful proxy of the redesigned referee header (same tokens/widgets).` through the function's closing `}`)
- In `_gallery()`, delete the two lines:
```dart
          _refereeHeader(context),
          const SizedBox(height: 12),
```

- [ ] **Step 10: Analyze gate + tests**

```bash
cd /d/khomasi_workspace/player && flutter analyze && flutter test
```
Expected: no new issues vs the Task 1 baseline (zero errors), `All tests passed!`. Common stragglers: other files importing the deleted components — grep and fix:
```bash
cd /d/khomasi_workspace/player && grep -rn "referee_page\|referee_profile\|active_match\|referee_match_card\|referee_stats\|score_board\|match_timer" lib test --include="*.dart" || echo CLEAN
```
Expected: `CLEAN`.

- [ ] **Step 11: Commit**

```bash
cd /d/khomasi_workspace && git add player && git status --short | grep "^[AMDR]" | grep -v player || true
```
Expected: nothing outside player staged. Then:
```bash
git commit -m "player: remove referee flow, add wrong-app guard for referee accounts

Signup always creates role player; referee pages/components deleted.
Referee functionality now lives in the referee/ app.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Final verification

**Files:** none (verification only; fixes go through the task they belong to)

- [ ] **Step 1: Both apps analyze clean and pass tests**

```bash
cd /d/khomasi_workspace/referee && flutter analyze && flutter test && cd ../player && flutter analyze && flutter test
```
Expected: no errors, all tests pass.

- [ ] **Step 2: Cross-contamination greps**

```bash
cd /d/khomasi_workspace && grep -rn "package:khomasi" referee/lib referee/test --include="*.dart" || echo REFEREE-CLEAN
grep -rln "RefereePage\|referee_page" player/lib --include="*.dart" || echo PLAYER-CLEAN
```
Expected: `REFEREE-CLEAN` and `PLAYER-CLEAN`.

- [ ] **Step 3: Player debug build**

```bash
cd /d/khomasi_workspace/player && flutter build apk --debug
```
Expected: `√ Built build/app/outputs/flutter-apk/app-debug.apk` (several minutes).

- [ ] **Step 4: Referee build — only if google-services.json has been provided**

```bash
ls /d/khomasi_workspace/referee/android/app/google-services.json && cd /d/khomasi_workspace/referee && flutter build apk --debug
```
If the file is absent, report: referee build pending the user's Firebase registration step (see `referee/README.md`) — not a failure. If present, also verify `lib/firebase_options.dart`'s `android` entry was updated per the README before building.

- [ ] **Step 5: Report**

Summarize to the user: what was built, verification results, and the one remaining manual step (register `com.example.referee` in Firebase, drop in `google-services.json`, update the two fields in `firebase_options.dart` — or hand me the json and I apply it).
