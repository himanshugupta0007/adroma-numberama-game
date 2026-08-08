# Firebase App Registration

Details for registering the Android and iOS apps in the Firebase console.

## Android app

| Field | Value |
|---|---|
| Android package name | `com.adroma.numberama` |
| App nickname (optional) | Numberama (Android) |
| Debug SHA-1 | `8A:5A:BB:FD:4A:51:BC:C4:2F:BB:90:B4:1A:E6:05:AA:43:6D:A8:F5` |
| Debug SHA-256 | `32:F8:E7:53:2C:7E:B4:42:12:19:E3:43:60:C9:4E:DF:AF:BF:2B:E0:97:61:A3:DB:8F:CB:28:BF:17:68:55:93` |

Notes:
- SHA fingerprints above are from `~/.android/debug.keystore`. The release build currently signs with this same debug key (see `android/app/build.gradle.kts`), so this SHA is enough for now — add it under Project Settings → your app → SHA certificate fingerprints.
- If a real release keystore is set up later for the Play Store, add that keystore's SHA-1/SHA-256 too (Firebase supports multiple fingerprints per app).
- SHA fingerprints are only required for Google Sign-In, Dynamic Links, or Phone Auth — skip them for Analytics/Crashlytics/Messaging only.
- After registering, download `google-services.json` and place it in `android/app/`.

## iOS app

| Field | Value |
|---|---|
| iOS bundle ID | `com.adroma.numberama` |
| App nickname (optional) | Numberama (iOS) |
| App Store ID | leave blank until published |

Notes:
- After registering, download `GoogleService-Info.plist` and place it in `ios/Runner/`, and add it to the Xcode project so it's bundled.

## Next steps

Once both config files (`google-services.json`, `GoogleService-Info.plist`) are added, wire up `firebase_core` (and any other Firebase packages needed) in `pubspec.yaml` and add the platform init code.

### Status: done (Android + iOS)

- `google-services.json` in `android/app/`, `GoogleService-Info.plist` in
  `ios/Runner/` (both gitignored - see `.gitignore`).
- `firebase_core` + `firebase_analytics` added to `pubspec.yaml`.
- Android: `com.google.gms.google-services` Gradle plugin applied
  (`android/settings.gradle.kts` + `android/app/build.gradle.kts`).
- iOS: `GoogleService-Info.plist` added to the Runner target's Resources
  build phase in `Runner.xcodeproj` (was a plain filesystem copy before,
  which Xcode won't bundle on its own without this - this project's Xcode
  project format predates the newer auto-syncing folder references).
  Bumped `IPHONEOS_DEPLOYMENT_TARGET` 13.0 → 15.0 (`ios/Podfile` +
  `Runner.xcodeproj`) since `firebase_analytics`'s podspec requires iOS
  15.0+.
- `lib/firebase_options.dart` - hand-written from the two config files
  above (no `flutterfire` CLI available in this environment to generate it
  interactively). Only `android`/`ios` are populated; web/macOS/Windows/
  Linux throw `UnsupportedError` since no Firebase app is registered for
  them yet. If `flutterfire configure` ever gets run later (e.g. to add a
  web app), it's safe to let it overwrite this file - same shape either way.
- `Firebase.initializeApp()` called first thing in `lib/main.dart`.
- `lib/state/analytics_service.dart` - `AnalyticsService` wrapping the 4
  custom events from Step 3/4 below (`mode_played`, `daily_challenge_complete`,
  `iap_purchase`, `ad_shown`). Exposed as both `AnalyticsService.instance`
  (for Flame code with no `ref`) and `analyticsServiceProvider`.
  **Not yet wired to real call sites** - see Step 4 for where each belongs.
- Verified both platforms actually build with this in place:
  `flutter build apk --debug` and `flutter build ios --debug --no-codesign`
  both succeed.

Step 2 — Add packages

flutter pub add firebase_core firebase_analytics

Then follow the flutterfire configure CLI (via dart pub global activate flutterfire_cli then flutterfire configure) — this auto-wires the platform config instead of hand-editing Gradle/Podfile, much less error-prone than manual setup.

One thing worth knowing before you wire anything: session_start is one of Firebase's automatically collected events — you don't need to log it manually, it fires on its own once Firebase is initialized. Same goes for ad_impression if you link AdMob to Firebase in the console (Firebase → Project Settings → Integrations → AdMob) — impressions get logged automatically without any code. That means your real manual work is just 3 custom events: mode_played, daily_challenge_complete, and iap_purchase (plus ad_shown if you want your own version instead of relying on the AdMob-linked auto one).

Step 3 — Cursor prompt for the AnalyticsService

Add Firebase Analytics to my Flutter + Flame game "Numberama".

1. In lib/state/, create analytics_service.dart with a class AnalyticsService
   that wraps FirebaseAnalytics.instance. Keep it framework-agnostic — no
   Flame or widget imports — so it can be called from both Flame components
   and Flutter widgets.

   Add these methods:
    - logModePlayed(String mode) → logs event "mode_played" with
      parameter {"mode": mode} (mode is "classic" or "rush")
    - logDailyChallengeComplete({required int streak, required int score,
      required bool success}) → logs event "daily_challenge_complete" with
      those as parameters
    - logIapPurchase({required String productId, required double value,
      required String currency}) → call FirebaseAnalytics.instance.logPurchase()
      with these mapped to the standard purchase event fields
    - logAdShown(String adType) → logs event "ad_shown" with
      parameter {"ad_type": adType} (adType is "banner", "interstitial",
      or "rewarded")

2. In main.dart, initialize Firebase before runApp():
   WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp();

3. Expose AnalyticsService via a Riverpod provider (analyticsServiceProvider)
   so it can be read from anywhere with ref.read().

Do not add any UI changes. This is infrastructure only — I'll wire the
actual call sites myself in the next step.

Step 4 — Where each call actually goes

Event	Fire it from
mode_played	Start Screen, right when the Play button is tapped, after mode is selected — analytics.logModePlayed(selectedMode)
daily_challenge_complete	Inside your Daily Challenge Engine, at the point it evaluates win/loss and updates the streak — call after streak is updated so you can pass the fresh count
iap_purchase	Inside your in_app_purchase purchaseStream.listen() callback, only after you've verified the purchase (not on the initial pending state)
ad_shown	In your ad wrapper's onAdShowedFullScreenContent callback for interstitial/rewarded, and onAdLoaded for banner — this is only needed if you're not relying on the AdMob-Firebase auto-linked ad_impression event

Step 5 — Verify it's actually working
Firebase Console → Analytics → DebugView shows events in near real-time, but you need to explicitly enable debug mode first:

Android: adb shell setprop debug.firebase.analytics.app <package_name>
iOS: add -FIRAnalyticsDebugEnabled as a launch argument in Xcode's scheme editor

Without this, events can take 24 hours to show up in the normal dashboard — DebugView is how you confirm wiring is correct same-day.