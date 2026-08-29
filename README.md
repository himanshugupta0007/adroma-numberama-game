# Numberama

A number-matching puzzle game built with Flutter and [Flame](https://flame-engine.org/). Clear the board by tapping pairs of tiles that match — either the same value, or two values that sum to 10 — before a rising stack of new rows reaches the top.

## Gameplay

- **Tap two tiles with the same number** to clear them.
- **Or two tiles that add to 10** — like 4 and 6.
- Clear the whole board before it reaches the top to win.

### Modes

- **Classic** — a rising-stack board. New rows are added on a timer (`Difficulty.autoRowIntervalSeconds`); survive and clear tiles faster than the stack grows. Difficulty (Easy / Medium / Hard) controls row-add pace, board height, and starting fill (see `lib/state/difficulty.dart`).
- **Daily Challenge** — a fixed 9×8 board shared by every player within the same cycle (a new cycle unlocks every 10 hours, see `dailyCycleDuration`), played against a 60-second countdown. Difficulty tier rotates deterministically per cycle.
- **Rush** — timed mode (pill shown in the HUD); shares Classic's rules today.

Progress carries over via an XP/level system (`lib/state/level_calculator.dart`), with local persistence, streaks, and achievement toasts.

## Tech stack

- **Flutter** (SDK `>=3.16.0`) / Dart `>=3.0.0`
- **Flame** — game engine for the grid/tile rendering and effects
- **Riverpod** — state management
- **Hive** — local persistence (preferences, player progress)
- **Firebase** (Core + Analytics)
- **Google Mobile Ads**
- Plus: `flutter_local_notifications`, `audioplayers`, `share_plus`, `in_app_review`, `confetti`

## Project structure

```
lib/
  game/       Flame components — grid, tiles, selection logic
  state/      Game state, difficulty/level curves, progress, preferences
  services/   Ads, audio, notifications, rate prompts
  ui/         Screens — home, gameplay, daily, results, settings
  widgets/    Shared UI pieces (buttons, dialogs, banners)
  theme/      Colors, text styles, app theme
assets/
  image/      App icon source
  sounds/     SFX (match, mismatch, power-up, countdown, game over)
doc/          Release, Firebase setup, and planning notes
```

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.16.0`
- Android Studio / Xcode for platform builds
- A Firebase project registered for `com.adroma.numberama` (Android & iOS) — see [`doc/firebase-setup.md`](doc/firebase-setup.md). Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.

### Setup

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Test

```bash
flutter test
```

### Build

```bash
flutter build apk      # Android
flutter build ios      # iOS
flutter build web       # Web
```

App icons are generated from `assets/image/icon/img.png` — after changing it, regenerate both platforms with:

```bash
dart run flutter_launcher_icons
```

## Documentation

- [`doc/firebase-setup.md`](doc/firebase-setup.md) — Firebase app registration details
- [`doc/release-guide.md`](doc/release-guide.md) — release process
- [`doc/play-store-release-checklist.md`](doc/play-store-release-checklist.md) — Play Store checklist
- [`doc/release-notes.md`](doc/release-notes.md) — release notes
- [`doc/remaining-work.md`](doc/remaining-work.md) — outstanding work / known gaps
- [`doc/iap-remove-ads-plan.md`](doc/iap-remove-ads-plan.md) — planned "Remove Ads" IAP

## License

See [`LICENSE`](LICENSE).
