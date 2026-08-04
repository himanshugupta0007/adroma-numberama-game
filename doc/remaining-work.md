# Remaining Work

Punch list of what's left in the app, excluding AdMob and Firebase integration (tracked separately).

## Settings metadata (placeholders)
- ~~support email~~ — done, set to `himanshugupta0007@gmail.com`.
- ~~privacy policy URL~~ — done, points to `https://himanshugupta0007.github.io/adroma-game-policies/`.
- ~~app version~~ — done, footer now reads the real version via `package_info_plus`.

## In-app purchases
- `lib/ui/settings_screen.dart:232-237` — "Remove Ads" row is disabled, no purchase flow.
- `lib/ui/settings_screen.dart:238-244` — "Restore Purchases" shows a "coming soon" dialog.
- `in_app_purchase` package is not a dependency — no IAP integration exists.

## Store listing / cross-promo
- `lib/ui/settings_screen.dart:294-299` — "Rate Numberama" doesn't launch a real store URL.
- "More Games" row hidden for now (was a dead stub with no destination screen) — re-add once a games-list screen exists.

## Gameplay power-ups
- `lib/ui/gameplay/power_bar.dart:54-56` and `:65-66` — after the one free use, shuffle/hint show "coming soon" dialogs. No fallback/alternate unlock path exists if ads aren't wired.

## Sound — missing clips
- `lib/game/tile_component.dart:94-96` — tile-tap SFX not implemented. - Not required
- `lib/game/selection_manager.dart:115-117` — "new row added" SFX not implemented.- not required
- Only 5 sound assets exist in `assets/sounds/` (match, mismatch, power-up, final-countdown, game-over). - done

## Daily Challenge — not truly deterministic
- `lib/state/difficulty.dart:88-95` — no seeded board generator yet; "today's board" is generated the same as a random Classic round, despite the UI implying a shared daily puzzle.

## Docs & tests
- `README.md` is still Flutter's default boilerplate — no game-specific setup/build docs.
- `test/game/numberama_game_test.dart` exists but has zero actual tests.
- No test coverage for: Settings screen, notifications flow, share flow, results screen, or preferences persistence.
